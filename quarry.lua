-- Quarry Turtle v1.1: local coordinates, durable checkpoints, bounded vein mining.
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
if argv[1]=='config' then
  print('[Quarry] Edit '..CP..' before init. Dimensions are locked after init.'); return
end
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
if argv[1]=='init' then
  assert(not s,'Existing job: keep its state; use a fresh turtle for a new quarry.')
  assert(peripheral.hasType('back','inventory'),'Place the output chest directly behind the turtle before init.')
  local anchor={type=peripheral.getType('back'),size=peripheral.wrap('back').size()}
  s={anchor=anchor,seq=0,p={x=0,y=0,z=0,d=0},route={},index=1,phase='work',seen={},vein=nil,
     shape={w=c.width,l=c.length,h=c.depth}}
  save(); log('Initialized. Chest behind; footprint extends forward and right. Run quarry to start.'); return
elseif not s then error('Run quarry init at the starting corner first.',0) end
assert(s.shape.w==c.width and s.shape.l==c.length and s.shape.h==c.depth,
 'Do not change dimensions during a job.')
if argv[1]=='status' then
  log('Phase '..s.phase..'; cell '..s.index..'; fuel '..fuel())
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
      s.phase='paused'; save(); log('Paused: '..s.service.reason..'. Fix the issue, then quarry continue.'); return false
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
-- A cell clears the band above/at/below its centre: depths 2,5,8,...
local function cell(i)
  local band=math.floor((i-1)/(c.width*c.length)); local n=(i-1)%(c.width*c.length)
  local x=math.floor(n/c.length); local z=n%c.length
  if x%2==1 then z=c.length-1-z end
  return {x=x,y=math.min(2+3*band,c.depth),z=z}
end
local total=math.ceil(c.depth/3)*c.width*c.length
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
  s.recovery={hypotheses=hypotheses,pause=s.service and s.service.pause or false,
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
        -- Reanchor at the chest. Restart the current cell, including its vein
        -- search, rather than trusting the interrupted operation's outcome.
        s.p={x=0,y=0,z=0,d=2}; s.route={}; s.vein=nil
        s.service={path={},at=0,pause=r.pause,reason=r.reason}
        s.phase='dock'; s.recovery=nil; save()
        log('Starting chest found. Position reset; resuming saved quarry cell '..s.index..'.')
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
if argv[1]=='return' and s.phase=='work' then requestService('User requested return',true) end
if s.phase=='paused' or s.phase=='done' then log('Phase: '..s.phase); return end
-- Resume first services the saved route, then resumes a saved vein or quarry cell.
local ok,err=pcall(function()
  if s.pending or s.recovery then homeRecovery() end
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
        if p.y>1 then guardedDig('up') end
        if p.y<c.depth then guardedDig('down') end
      end
      if vein() then
        s.index=s.index+1; save()
        if s.index<=total and (s.index-1)%(c.width*c.length)==0 then
          log('Band finished; next cell '..s.index..'/'..total)
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
