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
    if steam.RestartAppIfNecessary(3070970) {
        log.info("Launching app through steam...")
        return 
    }
    
    err_msg: steam.SteamErrMsg
    if err := steam.InitFlat(&err_msg); err != .OK {
        err_str := string(cast(cstring)&err_msg[0])
        log.panicf("steam.InitFlat failed with code '{}' and message \"{}\"", err, err_str)
    }
    log.assert(steam.User_BLoggedOn(steam.User()), "User is not logged in to steam")
    log.info("Steam User Name:", string(steam.Friends_GetPersonaName(steam.Friends())))
    log.info("Steam User State:", steam.Friends_GetPersonaState(steam.Friends()))
    steam_user.user = steam.User()
    
    steam.Client_SetWarningMessageHook(steam.Client(), _steam_debug_text_hook)

    steam.ManualDispatch_Init()
    
    if steam.GetHSteamPipe() == 0 {
        log.panic("Failed to get valid Steam pipe handle")
    }
    
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

steam_run_callbacks :: proc() {
    temp_mem := make([dynamic]byte, context.temp_allocator)

    steam_pipe := steam.GetHSteamPipe()
    if steam_pipe == 0 {
        log.error("Invalid Steam pipe handle in steam_run_callbacks")
        return
    }
    
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
                steam.ManualDispatch_FreeLastCallback(steam_pipe)
                return
            }
            
            // call identified by call_completed->m_hAsyncCall
            _steam_handle_api_call_result(call_completed, temp_call_res)
            
        case .GameOverlayActivated:
            _onGameOverlayActivated(cast(^steam.GameOverlayActivated)callback.pubParam)
        
        case .SteamRelayNetworkStatus:
            _onSteamRelayNetworkStatus(cast(^steam.SteamRelayNetworkStatus)callback.pubParam)
        
        case .SteamNetConnectionStatusChangedCallback:
            _onConnectionStatusChanged(cast(^steam.SteamNetConnectionStatusChangedCallback)callback.pubParam)
        case:
            fmt.println("Unhandled Callback:", callback.iCallback)
        }

        steam.ManualDispatch_FreeLastCallback(steam_pipe)
    }
}

_onGameOverlayActivated :: proc(data: ^steam.GameOverlayActivated) {
    fmt.println("Is overlay active =", data.bActive)
}

_onSteamRelayNetworkStatus :: proc(data: ^steam.SteamRelayNetworkStatus) {
    fmt.printfln("[STEAM] --- SteamRelayNetworkStatus")
    fmt.printfln("    eAvail = %v", data.eAvail)
    fmt.printfln("    bPingMeasurementInProgress = %v", data.bPingMeasurementInProgress)
    fmt.printfln("    eAvailNetworkConfig = %v", data.eAvailNetworkConfig)
    fmt.printfln("    eAvailAnyRelay = %v", data.eAvailAnyRelay)
    fmt.printfln("    debugMsg = %s", steam_dbgmsg_to_string(&data.debugMsg))
}

_onConnectionStatusChanged :: proc(data: ^steam.SteamNetConnectionStatusChangedCallback) {
    fmt.printfln("[STEAM] --- SteamNetConnectionStatusChangedCallback")
    fmt.printfln("    hConn: %v", data.hConn)
    fmt.printfln("    eOldState: %v", data.eOldState)
    fmt.printfln("    info: %v", steam_connectioninfo_to_string(&data.info))
    
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

steam_dbgmsg_to_string :: proc(msg: ^[256]u8) -> string {
    // Find the length of the message (up to the null terminator)
    msg_len := 0
    for i := 0; i < len(msg); i += 1 {
        if msg[i] == 0 {
            msg_len = i
            break
        }
    }
    
    msg_str, err := strings.clone_from_bytes(msg[:msg_len], context.temp_allocator)
    if err != .None {
        log.error("strings.clone_from_bytes failed with error:", err)
    }
    
    return msg_str
}

cstring_to_string :: proc(bytes: []u8) -> string {
    for i in 0..<len(bytes) {
        if bytes[i] == 0 {
            return string(bytes[0:i])
        }
    }
    return string(bytes)
}

steam_connectioninfo_to_string :: proc(conn_info: ^steam.SteamNetConnectionInfo) -> string {
    return fmt.tprintf(
        "SteamNetConnectionInfo:\n" +
        "  identityRemote: {}\n" +
        "  nUserData: {}\n" +
        "  hListenSocket: {}\n" +
        "  addrRemote: {}\n" +
        "  idPOPRemote: {}\n" +
        "  idPOPRelay: {}\n" +
        "  eState: {}\n" +
        "  eEndReason: %v\n" +
        "  szEndDebug: \"{}\"\n" +
        "  szConnectionDescription: \"{}\"\n" +
        "  nFlags: {}\n",
        conn_info.identityRemote,
        conn_info.nUserData,
        conn_info.hListenSocket,
        conn_info.addrRemote,
        conn_info.idPOPRemote,
        conn_info.idPOPRelay,
        conn_info.eState,
        conn_info.eEndReason,
        cstring_to_string(conn_info.szEndDebug[:]),
        cstring_to_string(conn_info.szConnectionDescription[:]),
        conn_info.nFlags
    )
}