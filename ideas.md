## GOAL: 
## Watch shader files for changes, and automatically recompile when needed
- Probably in main loop
- Every 1 second:
  1. Loop through every hlsl file and get the last time it was updated.
  2. If the last time it was updated is after the last time it was checked, find all pipelines using that shader and set them to nil
