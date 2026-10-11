-- Optional: copy this to /startup.lua AFTER initializing your turtle.
if fs.exists('quarry-data/state.a') or fs.exists('quarry-data/state.b') then
  shell.run('quarry')
end
