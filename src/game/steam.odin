package game

import "base:runtime"

import "core:fmt"
import "core:log"
import "core:c"
import "core:mem"
import "core:strings"

import steam "../../third_party/steamworks"


steam_user: struct {
    user: ^steam.IUser
}

number_of_current_players: int

steam_init :: proc () {
    APP_ID :: 3070970 
    if steam.RestartAppIfNecessary(APP_ID) {
        log.info("Launching app through steam...")
        return 
    }
    
    err_msg: steam.SteamErrMsg
    if err := steam.InitFlat(&err_msg); err != .OK {
        err_str := string(cast(cstring)&err_msg[0])
        log.panicf("steam.InitFlat failed with code '{}' and message \"{}\"", err, err_str)
    }
    
    steam.Client_SetWarningMessageHook(steam.Client(), _steam_debug_text_hook)

    steam.ManualDispatch_Init()

    log.assert(steam.User_BLoggedOn(steam.User()), "User is not logged in to steam")

    log.info("Steam User Name:", string(steam.Friends_GetPersonaName(steam.Friends())))
    log.info("Steam User State:", steam.Friends_GetPersonaState(steam.Friends()))
    
    steam_user.user = steam.User()
}

steam_cleanup :: proc() {
    log.info("Shutting down Steamworks.")
    steam.Shutdown()
}

_steam_debug_text_hook :: proc "c" (severity: c.int, debugText: cstring) {
    context = ctx
    // if you're running in the debugger, only warnings (nSeverity >= 1) will be sent
    // if you add -debug_steamapi to the command-line, a lot of extra informational messages will also be sent
    log_message := string(debugText) // Convert C string to Odin string
    fmt.println("[STEAM DEBUG Hook][Severity: %v] %s", severity, log_message)

    if severity >= 1 {
        runtime.debug_trap()
    }
}

run_steam_callbacks :: proc() {
    temp_mem := make([dynamic]byte, context.temp_allocator)

    steam_pipe := steam.GetHSteamPipe()
    steam.ManualDispatch_RunFrame(steam_pipe)
    callback: steam.CallbackMsg

    for steam.ManualDispatch_GetNextCallback(steam_pipe, &callback) {
        // Check for dispatching API call results
        #partial switch callback.iCallback {
        case .SteamAPICallCompleted:
            fmt.println("CallResult: ", callback)

            call_completed := transmute(^steam.SteamAPICallCompleted)callback.pubParam
            resize(&temp_mem, int(callback.cubParam))
            temp_call_res, ok := mem.alloc(int(callback.cubParam), allocator = context.temp_allocator)
            
            if !steam.ManualDispatch_GetAPICallResult(steam_pipe, call_completed.hAsyncCall, temp_call_res, callback.cubParam, callback.iCallback, &{}) {
                log.errorf("Failed to get steam api call result for callback: %s", callback.iCallback)
                return
            }
            
            // call identified by call_completed->m_hAsyncCall
            _steam_handle_api_call_result(call_completed, temp_call_res)
            
        case .GameOverlayActivated:
            fmt.println("GameOverlayActivated")
            _onGameOverlayActivated(transmute(^steam.GameOverlayActivated)callback.pubParam)
        }

        steam.ManualDispatch_FreeLastCallback(steam_pipe)
    }
}

_onGameOverlayActivated :: proc(using data: ^steam.GameOverlayActivated) {
    fmt.println("Is overlay active =", bActive)
}

_onGetNumberOfCurrentPlayers :: proc(data: ^steam.NumberOfCurrentPlayers) {
    fmt.println("[get_number_of_current_players] Number of players currently playing:", data.cPlayers)
    number_of_current_players = int(data.cPlayers)
}

steam_get_current_player_count :: proc() {
    fmt.println("[steam_get_current_player_count] Getting number of current players.")
    hSteamApiCall := steam.UserStats_GetNumberOfCurrentPlayers(steam.UserStats())
}

_steam_handle_api_call_result :: proc(call: ^steam.SteamAPICallCompleted, temp_call_res: rawptr) {
    fmt.println("   call_completed", call)
    #partial switch call.iCallback {
    case .NumberOfCurrentPlayers:
        _onGetNumberOfCurrentPlayers(transmute(^steam.NumberOfCurrentPlayers)temp_call_res)
    }
    
}