-- Optional spare: quarry creates this automatically when no startup exists.
if fs.exists('quarry-data/state.a') or fs.exists('quarry-data/state.b') then
  shell.run('quarry')
end
