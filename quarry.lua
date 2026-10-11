-- Quarry Turtle v1.2: guided setup, selective tunnels, local coordinates, durable checkpoints, bounded vein mining.
-- Origin is the turtle's starting block. +Z is forward, +X is right, Y is down.
local argv = {...}
local ROOT = 'quarry-data'
fs.makeDir(ROOT)
local function readFile(p)
  if not fs.exists(p) then return nil end
  local h = assert(fs.open(p, 'r')); local s = h.readAll(); h.close()
  return assert(textutils.unserialize(s), 'Invalid file: '..p)
end
local function writeFile(p, v)
  local h = assert(fs.open(p, 'w')); h.write(textutils.serialize(v)); h.close()
end
local defaults = {
  width=16, length=16, depth=64, fuelMargin=64, fuelTarget=2000,
  retries=12, veinLimit=128, veinDepth=24, discardTrash=true,
  fuel={['minecraft:coal']=true, ['minecraft:charcoal']=true},
  trash={['minecraft:dirt']=true, ['minecraft:grass_block']=true,
    ['minecraft:cobblestone']=true, ['minecraft:stone']=true,
    ['minecraft:gravel']=true, ['minecraft:andesite']=true,
    ['minecraft:diorite']=true, ['minecraft:granite']=true,
    ['minecraft:cobbled_deepslate']=true, ['minecraft:deepslate']=true,
    ['minecraft:tuff']=true, ['minecraft:netherrack']=true},
  protected={['minecraft:bedrock']=true, ['minecraft:chest']=true,
    ['minecraft:trapped_chest']=true, ['minecraft:barrel']=true,
    ['minecraft:spawner']=true, ['minecraft:end_portal_frame']=true},
}
local CP=ROOT..'/config'; local SP=ROOT..'/state'
if not fs.exists(CP) then writeFile(CP, defaults) end
local c=readFile(CP)
for _,k in ipairs({'width','length','depth','fuelMargin','fuelTarget','retries','veinLimit','veinDepth'}) do
  assert(type(c[k])=='number' and c[k]>=1 and c[k]%1==0, 'Invalid config: '..k)
end
assert(type(c.trash)=='table' and type(c.fuel)=='table' and type(c.protected)=='table')
-- Alternating files keep the preceding complete checkpoint after interrupted writes.
local s
for _,p in ipairs({SP..'.a',SP..'.b'}) do
  local ok,v=pcall(readFile,p)
  if ok and v and type(v.seq)=='number' and (not s or v.seq>s.seq) then s=v end
end
local function save()
  s.seq=s.seq+1; writeFile(SP..(s.seq%2==0 and '.a' or '.b'),s)
end
local function log(msg) print('[Quarry] '..msg) end
local function copy(v) return {x=v.x,y=v.y,z=v.z,d=v.d} end
local function same(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
local function key(p) return p.x..','..p.y..','..p.z end
local function fuel() local f=turtle.getFuelLevel(); return f=='unlimited' and math.huge or f end
local function capacity() local f=turtle.getFuelLimit(); return f=='unlimited' and math.huge or f end
local function answer(prompt)
  write(prompt..' ')
  local v=read(); return v:match('^%s*(.-)%s*$')
end
local function numberQuestion(label,default,maximum)
  while true do
    local raw=answer(label..' ['..default..']:')
    if raw=='' then return default end
    if raw:lower()=='q' then return nil end
    local n=tonumber(raw)
    if n and n>=1 and n<=maximum and n%1==0 then return n end
    print('Enter a whole number from 1 to '..maximum..'.')
  end
end
local function ensureStartup()
  -- Create our startup file only when there is no existing startup program.
  if fs.exists('startup.lua') or fs.exists('startup') then return end
  local program=s.program or shell.getRunningProgram()
  local h=assert(fs.open('startup.lua','w'))
  h.write('-- Automatically resume the saved mining job.\n')
  h.write('shell.run('..string.format('%q',program)..')\n'); h.close()
  log('Automatic restart enabled.')
end
local function settingsMenu()
  while true do
    print('\nTrash settings')
    print('1 Add a block to trash (ignore it)')
    print('2 Remove a block from trash (keep it)')
    print('3 Show the trash list')
    print('4 Toggle dropping trash: '..(c.discardTrash and 'ON' or 'OFF'))
    print('Enter or q: finish')
    local v=answer('Choose:'):lower()
    if v=='' or v=='q' then return end
    if v=='1' or v=='2' then
      local name=answer('Block/item ID (example minecraft:stone):')
      if name:match('^[%w_]+:[%w_/%.-]+$') then
        if v=='1' then c.trash[name]=true else c.trash[name]=nil end
        writeFile(CP,c); print('Saved.')
      else print('Use a full block/item ID, with a colon.') end
    elseif v=='3' then
      local names={}; for name,enabled in pairs(c.trash) do if enabled then names[#names+1]=name end end
      table.sort(names); for _,name in ipairs(names) do print(name) end
    elseif v=='4' then c.discardTrash=not c.discardTrash; writeFile(CP,c)
    else print('Choose 1, 2, 3 or 4.') end
  end
end
if argv[1]=='help' then
  print('Quarry Turtle 1.2 - tunnel miner')
  print('quarry          Start or resume')
  print('quarry status   Show progress')
  print('quarry settings Change the trash list')
  print('quarry return   Go home and pause')
  print('quarry new      Set up a new job at home')
  print('Hold Ctrl+T to stop the running program.')
  return
end
if argv[1]=='settings' or argv[1]=='config' then settingsMenu(); return end
local fresh=not s or argv[1]=='new'
if fresh then
  if argv[1] and argv[1]~='new' and argv[1]~='init' then
    print('No saved job yet. Run quarry to set up.'); return
  end
  if s and (s.pending or s.recovery or #s.route>0 or (s.phase~='done' and s.phase~='paused')) then
    print('Finish the job or return home before starting a new one.'); return
  end
  print('\nQuarry Turtle 1.2 - first-time setup')
  print('We dig tunnels and collect nearby ores.')
  print('Press Enter for each default, or q to cancel.')
  print('Length goes forward; width goes to the right.')
  local length=numberQuestion('Length in blocks',c.length,64); if not length then return end
  local width=numberQuestion('Width in blocks',c.width,64); if not width then return end
  local depth=numberQuestion('Depth below the turtle',c.depth,512); if not depth then return end
  print('\nPlace a chest directly BEHIND this turtle.')
  print('Put coal/charcoal in the first chest slots.')
  print('Face the turtle into the mining area.')
  print('Check that the area is safe to dig.')
  while true do
    local v=answer('Enter to start, or q to cancel:'):lower()
    if v=='q' then return end
    if peripheral.hasType('back','inventory') then break end
    print('No chest behind the turtle. Place it, then retry.')
  end
  local previousSeq=s and s.seq or 0
  if s then writeFile(ROOT..'/previous-job',s) end
  c.length=length; c.width=width; c.depth=depth; writeFile(CP,c)
  local anchor={type=peripheral.getType('back'),size=peripheral.wrap('back').size()}
  s={anchor=anchor,seq=previousSeq,p={x=0,y=0,z=0,d=0},route={},index=1,phase='work',seen={},vein=nil,
     layoutVersion=2,program=shell.getRunningProgram(),shape={w=c.width,l=c.length,h=c.depth}}
  save(); ensureStartup()
  log('Starting '..c.length..' long x '..c.width..' wide, '..c.depth..' blocks deep.')
elseif argv[1]=='init' then
  print('Already set up. Run quarry to resume.'); return
end
c.width=s.shape.w; c.length=s.shape.l; c.depth=s.shape.h
if argv[1]=='status' then
  log('Saved step '..s.index..'; fuel '..fuel())
  log('State: '..s.phase..'; depth '..s.p.y..' below start')
  if s.recovery then
    for i,h in ipairs(s.recovery.hypotheses) do
      log('Recovery hypothesis '..i..': '..key(h.p)..', facing '..h.p.d..', route '..#h.route)
    end
  else log('Position '..key(s.p)..', facing '..s.p.d) end
  if s.pending then print(textutils.serialize(s.pending)) end
  return
end
if argv[1]=='recover' then
  assert(s.pending,'No original uncertain action; run quarry for automatic chest recovery.')
  assert(argv[2]=='before' or argv[2]=='after','Use quarry recover before|after after checking the physical pose.')
  if argv[2]=='after' then
    s.p=copy(s.pending.after)
    if s.pending.route=='push' then s.route[#s.route+1]=copy(s.p)
    elseif s.pending.route=='pop' then table.remove(s.route)
    elseif s.pending.route=='out' then
      s.service.at=s.service.at+1
      s.route={}; for i=1,s.service.at do s.route[i]=copy(s.service.path[i]) end
    end
  end
  s.pending=nil; save(); log('Pose confirmed; run quarry to continue.'); return
end
local dx={0,1,0,-1}; local dz={1,0,-1,0}
local function inside(p) return p.x>=0 and p.x<c.width and p.z>=0 and p.z<c.length and p.y>=1 and p.y<=c.depth end
-- Persist intent before physical actions; unfinished actions trigger chest homing.
local function action(fn, after, route)
  s.pending={before=copy(s.p),after=copy(after),route=route,fuel=turtle.getFuelLevel()}; save()
  local ok,why=fn()
  if ok then
    s.p=copy(after)
    if route=='push' then s.route[#s.route+1]=copy(s.p)
    elseif route=='pop' then table.remove(s.route)
    elseif route=='out' then
      s.service.at=s.service.at+1
      s.route={}; for i=1,s.service.at do s.route[i]=copy(s.service.path[i]) end
    end
  end
  s.pending=nil; save(); return ok,why
end
local function face(d)
  while s.p.d~=d do
    local p=copy(s.p); p.d=(p.d+1)%4
    assert(action(turtle.turnRight,p),'Turn failed')
  end
end
local function refuelTo(n)
  n=math.min(n,capacity())
  for i=1,16 do
    local item=turtle.getItemDetail(i)
    if item and c.fuel[item.name] then
      turtle.select(i)
      while fuel()<n and turtle.getItemCount(i)>0 do
        if not turtle.refuel(1) then break end
      end
    end
  end
  turtle.select(1)
end
-- Enough for a failed hypothesis, retracing it, and the correct return.
local function reserve(n) return 3*(n+2)+c.fuelMargin end
local function freeSlots()
  local n=0; for i=1,16 do if turtle.getItemCount(i)==0 then n=n+1 end end; return n
end
local function trash()
  if not c.discardTrash or s.p.y<1 then return end
  -- Drop only into an empty mined block; never into a peripheral or liquid.
  local ok=turtle.inspectDown()
  if ok or peripheral.isPresent('bottom') then return end
  for i=1,16 do
    local v=turtle.getItemDetail(i)
    if v and c.trash[v.name] and not c.fuel[v.name] then turtle.select(i); turtle.dropDown() end
  end
  turtle.select(1)
end
local function guardedDig(side)
  local inspect=side=='up' and turtle.inspectUp or side=='down' and turtle.inspectDown or turtle.inspect
  local dig=side=='up' and turtle.digUp or side=='down' and turtle.digDown or turtle.dig
  local per=side=='up' and 'top' or side=='down' and 'bottom' or 'front'
  local exists,b=inspect()
  if not exists then return true end
  if b.name=='minecraft:water' or b.name=='minecraft:lava' then return true end
  if c.protected[b.name] or peripheral.isPresent(per)
    or b.name:find('shulker_box',1,true) or b.name:find('turtle',1,true) then
    error('Protected block: '..b.name,0)
  end
  if freeSlots()<2 then error('Inventory reserve reached',0) end
  local ok,why=dig(); if not ok then error('Cannot dig '..b.name..': '..tostring(why),0) end
  return true
end
local function step(target, mode)
  local side='front'; local move=turtle.forward
  if target.y<s.p.y then side='up'; move=turtle.up
  elseif target.y>s.p.y then side='down'; move=turtle.down
  elseif target.x~=s.p.x then face(target.x>s.p.x and 1 or 3)
  else face(target.z>s.p.z and 0 or 2) end
  assert(math.abs(target.x-s.p.x)+math.abs(target.y-s.p.y)+math.abs(target.z-s.p.z)==1,'Nonadjacent route')
  refuelTo(reserve(#s.route+1)+2)
  if (mode=='push' or mode=='out') and fuel()<=reserve(#s.route+1) then
    error('Fuel reserve reached',0)
  end
  if fuel()<1 then error('Out of fuel; stopped at '..key(s.p),0) end
  for _=1,c.retries do
    guardedDig(side)
    local p=copy(target); p.d=s.p.d
    local ok=action(move,p,mode)
    if ok then return end
    sleep(0.2) -- Wait for falling gravel or an entity; do not attack mobs.
  end
  error('Movement blocked at '..key(target),0)
end
local function homeStep()
  local n=#s.route
  if n>0 then step(n==1 and {x=0,y=0,z=0} or s.route[n-1],'pop') end
end
local function gotoWork(p)
  -- Work navigation follows previously excavated rows or digs within the footprint.
  while s.p.y~=p.y do
    step({x=s.p.x,y=s.p.y+(p.y>s.p.y and 1 or -1),z=s.p.z},'push')
  end
  while s.p.x~=p.x do step({x=s.p.x+(p.x>s.p.x and 1 or -1),y=s.p.y,z=s.p.z},'push') end
  while s.p.z~=p.z do step({x=s.p.x,y=s.p.y,z=s.p.z+(p.z>s.p.z and 1 or -1)},'push') end
end
local function chest()
  face(2)
  assert(peripheral.hasType('front','inventory'),'Output chest missing or unsupported; replace it behind origin.')
  if not s.anchor then
    s.anchor={type=peripheral.getType('front'),size=peripheral.wrap('front').size()}; save()
  end
end
local function unload()
  chest()
  for i=1,16 do
    turtle.select(i)
    if turtle.getItemCount(i)>0 and not turtle.drop() then error('Output chest full; empty it and run quarry.',0) end
    if turtle.getItemCount(i)>0 then error('Output chest full; empty it and run quarry.',0) end
  end
  turtle.select(1)
end
local function chestFuel(target)
  chest(); local inv=peripheral.wrap('front')
  -- Native suck cannot choose chest slots. Scan a fixed initial stack count,
  -- retaining nonfuel until the scan ends so returned items cannot loop forever.
  local count=0; for _ in pairs(inv.list()) do count=count+1 end
  refuelTo(target)
  for _=1,count do
    if fuel()>=target then break end
    local slot
    for i=1,16 do if turtle.getItemCount(i)==0 then slot=i; break end end
    if not slot then break end
    turtle.select(slot)
    if not turtle.suck() then break end
    refuelTo(target)
  end
  unload()
  if fuel()<target then error('Need more coal/charcoal. Put it at the front of the chest inventory, then run quarry.',0) end
end
local function requestService(reason, pause)
  log('Returning to surface: '..reason..' (route '..#s.route..', depth '..s.p.y..')')
  s.service={path={},at=0,pause=pause,reason=reason}
  for i,p in ipairs(s.route) do s.service.path[i]=copy(p) end
  s.phase='home'; save()
end
local function service()
  if s.phase=='home' then
    while #s.route>0 do homeStep() end
    if s.service.reset then s.service.path={} end
    s.phase='dock'; save()
  end
  if s.phase=='dock' then
    unload()
    if s.service.reason=='Quarry complete' then
      s.phase='done'; save(); log('Complete; inventory unloaded.'); return false
    end
    if s.service.pause then
      s.phase='paused'; save(); log('Paused: '..s.service.reason..'. Fix it, then run quarry.'); return false
    end
    local n=#s.service.path
    local needed=n+reserve(n)+64
    assert(needed<=capacity() or fuel()==math.huge,'Route exceeds fuel capacity; reduce depth/vein limits.')
    chestFuel(math.min(capacity(),math.max(c.fuelTarget,needed)))
    s.phase='out'; save()
  end
  if s.phase=='out' then
    while s.service.at<#s.service.path do
      local p=s.service.path[s.service.at+1]
      step(p,'out')
      -- Route is the completed outbound prefix, reconstructed after each checkpoint.
      s.route={}; for i=1,s.service.at do s.route[i]=copy(s.service.path[i]) end; save()
    end
    s.phase='work'; s.service=nil; save()
  end
  return true
end
-- A one-block-high tunnel grid. Two stone columns stay between long
-- tunnels; endpoint connectors and the entry shaft are scanned too.
local plan,bandStarts={},{}
local rows={}
for x=0,c.width-1,3 do rows[#rows+1]=x end
if c.width-1>rows[#rows]+1 then rows[#rows+1]=c.width-1 end
local previousDepth=0
for band=0,math.ceil(c.depth/3)-1 do
  local y=math.min(2+3*band,c.depth)
  bandStarts[band+1]=#plan+1
  for shaftY=previousDepth+1,y do plan[#plan+1]={x=0,y=shaftY,z=0,band=band+1} end
  local lastX=0
  for row,x in ipairs(rows) do
    local startZ=row%2==1 and 0 or c.length-1
    if row>1 then
      for connectorX=lastX+1,x do plan[#plan+1]={x=connectorX,y=y,z=startZ,band=band+1} end
    end
    -- The first point is already the shaft or connector endpoint.
    for offset=1,c.length-1 do
      local z=row%2==1 and offset or c.length-1-offset
      plan[#plan+1]={x=x,y=y,z=z,band=band+1}
    end
    lastX=x
  end
  previousDepth=y
end
local total=#plan
local function cell(i) return plan[i] end
-- Old excavation checkpoints used a different cell numbering scheme.
-- Remember their vertical band; convert only after reaching the chest.
if not s.layoutVersion and s.upgradeBand==nil then
  s.upgradeBand=math.floor((s.index-1)/(c.width*c.length)); save()
end
local function upgradeAtDock()
  if s.upgradeBand==nil then return end
  assert(#s.route==0 and s.p.x==0 and s.p.y==0 and s.p.z==0,'Update requires the starting chest.')
  s.index=bandStarts[s.upgradeBand+1] or total+1
  s.upgradeBand=nil; s.layoutVersion=2; s.vein=nil
  if s.service then s.service.path={}; s.service.at=0 end
  save(); log('Updated to tunnel mining. Existing depth progress kept.')
end
local function neighbour(p,d)
  local q=copy(p)
  if d==4 then q.y=q.y-1 elseif d==5 then q.y=q.y+1
  else q.x=q.x+dx[d+1]; q.z=q.z+dz[d+1] end
  return q
end
local function vein()
  if not s.vein then s.vein={stack={{p=copy(s.p),next=0}},count=0}; save() end
  while #s.vein.stack>0 do
    local v=s.vein; local f=v.stack[#v.stack]
    local parent=v.stack[#v.stack-1]
    local returning=f.next>=6 or v.count>=c.veinLimit or #v.stack>c.veinDepth
    if not same(s.p,f.p) and not (returning and parent and same(s.p,parent.p)) then gotoWork(f.p) end
    if f.next>=6 or v.count>=c.veinLimit or #v.stack>c.veinDepth then
      local parent=v.stack[#v.stack-1]
      if parent and not same(s.p,parent.p) then step(parent.p,'pop') end
      table.remove(v.stack); save()
    else
      local d=f.next; local q=neighbour(f.p,d)
      if inside(q) and not s.seen[key(q)] then
        local inspect
        if d==4 then inspect=turtle.inspectUp elseif d==5 then inspect=turtle.inspectDown
        else face(d); inspect=turtle.inspect end
        local ok,b=inspect()
        if ok and b.name~='minecraft:water' and b.name~='minecraft:lava' and not c.trash[b.name] then
          step(q,'push'); s.seen[key(q)]=true; v.count=v.count+1
          f.next=f.next+1; v.stack[#v.stack+1]={p=copy(q),next=0}; save()
        else f.next=f.next+1; save() end
      else f.next=f.next+1; save() end
    end
    trash(); refuelTo(reserve(#s.route+1)+4)
    if freeSlots()<2 or fuel()<=reserve(#s.route+1)+3 then
      requestService('Inventory or fuel reserve',false); return false
    end
  end
  s.vein=nil; save(); return true
end
-- Recovery keeps both pose hypotheses and updates them with the same physical
-- actions. Failed trials are naturally retraced by the next candidate's trail.
local function clone(v)
  if type(v)~='table' then return v end
  local t={}; for k,x in pairs(v) do t[k]=clone(x) end; return t
end
local function applyRecovery(h,op)
  if op=='right' then h.p.d=(h.p.d+1)%4; return end
  local q=copy(h.p)
  if op=='up' then q.y=q.y-1 elseif op=='down' then q.y=q.y+1
  else q.x=q.x+dx[q.d+1]; q.z=q.z+dz[q.d+1] end
  -- Erase loops in the physical trace, preserving a route rooted at origin.
  local found
  if q.x==0 and q.y==0 and q.z==0 then found=0
  else for i=#h.route,1,-1 do if same(q,h.route[i]) then found=i; break end end end
  if found then for i=#h.route,found+1,-1 do h.route[i]=nil end
  else h.route[#h.route+1]=copy(q) end
  h.p=q
end
local function eachHypothesis(fn)
  for _,h in ipairs(s.recovery.hypotheses) do fn(h) end
  for _,h in ipairs(s.recovery.failed or {}) do fn(h) end
end
local function compactHypotheses()
  local seen,unique={},{}
  for _,h in ipairs(s.recovery.hypotheses) do
    local k=key(h.p)..':'..h.p.d
    for _,p in ipairs(h.route) do k=k..';'..key(p) end
    if not seen[k] then seen[k]=true; unique[#unique+1]=h end
  end
  s.recovery.hypotheses=unique
  assert(#unique+#(s.recovery.failed or {})<=16,'Repeated recovery interruptions produced too many hypotheses; saved safely.')
end
local function beginRecovery()
  local pending=s.pending
  if not pending then return end
  local before={p=copy(pending.before),route=clone(s.route)}
  local after={p=copy(pending.after),route=clone(s.route)}
  if pending.route=='push' then after.route[#after.route+1]=copy(after.p)
  elseif pending.route=='pop' then table.remove(after.route)
  elseif pending.route=='out' then
    after.route={}
    for i=1,s.service.at+1 do after.route[i]=copy(s.service.path[i]) end
  end
  local hypotheses={before,after}
  -- Fuel is a useful ordering hint for movement, not a required dependency.
  if type(pending.fuel)=='number' and fuel()==pending.fuel-1 then hypotheses={after,before} end
  local resumePath=clone(s.service and s.service.path or s.route)
  local resumeVein=clone(s.vein)
  -- Digging precedes the move. Even if the move never happened, its target
  -- is cleared; preserve the DFS branch so ores beyond that block are found.
  if s.phase=='work' and resumeVein and pending.route=='push' then
    local frame=resumeVein.stack[#resumeVein.stack]
    if frame and frame.next<6 and same(pending.before,frame.p)
      and same(pending.after,neighbour(frame.p,frame.next)) then
      resumePath=clone(after.route)
      frame.next=frame.next+1; resumeVein.count=resumeVein.count+1
      resumeVein.stack[#resumeVein.stack+1]={p=copy(pending.after),next=0}
      s.seen[key(pending.after)]=true
    end
  end
  s.recovery={hypotheses=hypotheses,pause=s.service and s.service.pause or false,
    resumePath=resumePath,resumeVein=resumeVein,
    reason=s.service and s.service.reason or 'Interrupted action recovery'}
  s.pending=nil; s.phase='recovery'; compactHypotheses(); save()
  log('Uncertain action: homing to the starting chest without digging.')
end
local function settleRecoveryAction()
  local r=s.recovery; local pending=r.pending
  if not pending then return end
  local current=turtle.getFuelLevel()
  if pending.op~='right' and type(pending.fuel)=='number' and type(current)=='number' then
    -- Recovery never refuels between recording intent and settling its result.
    if current==pending.fuel-1 then
      eachHypothesis(function(h) applyRecovery(h,pending.op) end)
    elseif current~=pending.fuel then
      error('Fuel changed externally during recovery; stopped safely.',0)
    end
  else
    for _,list in ipairs({r.hypotheses,r.failed or {}}) do
      local n=#list
      for i=1,n do
        local moved=clone(list[i]); applyRecovery(moved,pending.op)
        list[#list+1]=moved
      end
    end
  end
  r.pending=nil; compactHypotheses(); save()
end
local function recoveryAction(op)
  local r=s.recovery
  r.pending={op=op,fuel=turtle.getFuelLevel()}; save()
  local fn=op=='right' and turtle.turnRight or op=='up' and turtle.up
    or op=='down' and turtle.down or turtle.forward
  local ok=fn()
  if ok then eachHypothesis(function(h) applyRecovery(h,op) end) end
  r.pending=nil; save(); return ok
end
local function recoveryFace(h,d)
  while h.p.d~=d do assert(recoveryAction('right'),'Recovery turn failed') end
end
local function anchorMatches()
  if not peripheral.hasType('front','inventory') then return false end
  if s.anchor then
    return peripheral.getType('front')==s.anchor.type and peripheral.wrap('front').size()==s.anchor.size
  end
  -- Legacy jobs created before v1.1 did not record a chest signature.
  local ok,b=turtle.inspect()
  return ok and (b.name=='minecraft:chest' or b.name=='minecraft:trapped_chest' or b.name=='minecraft:barrel')
end
local function homeRecovery()
  if s.pending then beginRecovery() end
  settleRecoveryAction()
  local r=s.recovery
  -- Check a pessimistic budget before starting any uncertain travel.
  local budget,shortest=0,math.huge
  for _,h in ipairs(r.hypotheses) do budget=budget+#h.route; shortest=math.min(shortest,#h.route) end
  if #r.hypotheses>0 then budget=2*budget-shortest end
  refuelTo(budget+c.fuelMargin)
  assert(fuel()>=budget+c.fuelMargin,
    'Insufficient fuel for chest recovery; waiting with saved hypotheses. Add allowed fuel and run quarry.')
  while #r.hypotheses>0 do
    local h=r.hypotheses[1]; local reachable=true
    log('Recovery trial: '..#h.route..' steps to the predicted origin.')
    while #h.route>0 do
      local n=#h.route; local q=n==1 and {x=0,y=0,z=0} or h.route[n-1]
      assert(math.abs(q.x-h.p.x)+math.abs(q.y-h.p.y)+math.abs(q.z-h.p.z)==1,
        'Invalid recovery trail; stopped safely.')
      local op,inspect
      if q.y<h.p.y then op='up'; inspect=turtle.inspectUp
      elseif q.y>h.p.y then op='down'; inspect=turtle.inspectDown
      else
        recoveryFace(h,q.x~=h.p.x and (q.x>h.p.x and 1 or 3) or (q.z>h.p.z and 0 or 2))
        op='forward'; inspect=turtle.inspect
      end
      local moved=false
      for _=1,c.retries do
        local exists,b=inspect()
        if exists and b.name~='minecraft:water' and b.name~='minecraft:lava' then break end
        assert(fuel()>c.fuelMargin,'Recovery fuel margin reached; stopped safely.')
        if recoveryAction(op) then moved=true; break end
        sleep(0.2)
      end
      if not moved then reachable=false; break end
    end
    if reachable then
      recoveryFace(h,2)
      if anchorMatches() then
        -- Reanchor, then replay the saved cleared route to the pending vein
        -- branch. A tunnel miner must not lose ores behind already mined air.
        s.p={x=0,y=0,z=0,d=2}; s.route={}; s.vein=r.resumeVein
        s.service={path=r.resumePath or {},at=0,pause=r.pause,reason=r.reason}
        s.phase='dock'; s.recovery=nil; save()
        log('Starting chest found. Resuming saved tunnel step '..s.index..'.')
        return
      end
    end
    -- Keep the failed candidate too: if an obstruction was temporary, the
    -- player can clear it and retry without reconstructing the turtle's pose.
    r.failed=r.failed or {}; r.failed[#r.failed+1]=table.remove(r.hypotheses,1); save()
  end
  r.hypotheses=r.failed or {}; r.failed=nil; save()
  error('Starting chest not found on any cleared route. Check chest/chunk loading or route obstruction; run quarry to retry. No blocks were dug.',0)
end

if argv[1]=='continue' and s.phase=='paused' then
  s.service.pause=false; s.phase='dock'; save()
end
if s.phase=='done' then
  print('Mining finished! Items are in the chest.')
  print('For a new job, face into the new area, then quarry new.'); return
end
if s.phase=='paused' then
  if argv[1]=='return' then print('Already paused at the starting chest.'); return end
  log('Paused: '..tostring(s.service and s.service.reason or 'User pause'))
  if answer('Fixed the issue? Enter to resume, q to exit:'):lower()=='q' then return end
  s.service.pause=false; s.phase='dock'; save()
end
-- Resume first services the saved route, then resumes a saved vein or quarry cell.
local ok,err=pcall(function()
  if s.pending or s.recovery then homeRecovery() end
  if argv[1]=='return' then
    if s.phase=='work' or s.phase=='out' then
      local destination=s.phase=='out' and clone(s.service.path) or nil
      requestService('User requested return',true)
      if destination then s.service.path=destination; save() end
    elseif s.service then
      s.service.pause=true; s.service.reason='User requested return'; save()
    end
  end
  if s.upgradeBand~=nil then
    if s.phase~='dock' then
      requestService('Updating to tunnel mining',false); s.service.reset=true; save()
      while #s.route>0 do homeStep() end
      s.phase='dock'; save()
    end
    upgradeAtDock()
  end
  if s.index==1 and s.phase=='work' and #s.route==0 and not s.vein then
    requestService('Initial chest/fuel check',false)
  end
  while true do
    if s.phase~='work' then if not service() then return end end
    if s.index>total then
      requestService('Quarry complete',true); s.service.reason='Quarry complete'; save()
      service(); return
    end
    refuelTo(reserve(#s.route+1)+64); trash()
    if fuel()<=reserve(#s.route+1)+32 or freeSlots()<2 then
      requestService('Inventory or fuel reserve',false)
    else
      if not s.vein then
        local p=cell(s.index); gotoWork(p)
      end
      if vein() then
        s.index=s.index+1; save()
        if s.index%16==0 then log('Tunnel progress: '..(s.index-1)..'/'..total..'; depth '..s.p.y) end
        if s.index<=total and plan[s.index].band~=plan[s.index-1].band then
          log('Tunnel level finished. Returning to the chest.')
          -- Reset to origin each band: shorter, predictable return paths.
          requestService('Band complete',false); s.service.reset=true; save()
        end
      end
    end
  end
end)
if not ok then
  log(tostring(err))
  if s.pending or s.recovery then
    log('Recovery saved. Run quarry (or let startup run it) to retry automatic chest homing.'); return
  end
  -- An error during a return must not overwrite the original outbound route.
  if s.phase=='work' then
    requestService(tostring(err),err~='Fuel reserve reached' and err~='Inventory reserve reached')
    local safe,why=pcall(service)
    if not safe then log('Return stopped: '..tostring(why)..'. Position '..key(s.p)..'; run quarry after fixing.') end
  else log('Job saved at '..key(s.p)..'; fix issue and run quarry.') end
end
