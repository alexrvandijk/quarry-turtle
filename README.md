# Mole 1.3.1

**A little mining robot that digs tunnels, finds nearby ores, and brings them back to your chest.**

Run `mole`, answer three questions, and your turtle gets to work.

## What you need

- Minecraft with **CC: Tweaked**.
- A **mining turtle** with a diamond pickaxe upgrade. A normal or advanced mining turtle works.
- A chest and some coal or charcoal. Put one stack in the chest to start.
- Internet downloads enabled for turtles. If your server blocks them, ask its owner.

## 1. Download the program onto your turtle

Right-click the mining turtle to open its screen. Type this command and press Enter:

```text
wget https://raw.githubusercontent.com/alexrvandijk/quarry-turtle/main/mole.lua mole
```

This downloads Mole and saves it on your turtle as **mole**.

## 2. Place the turtle and chest

1. Choose an area you are happy for the turtle to mine underneath.
2. Put the turtle at the **near-left corner**, facing into the area.
3. Put the chest **directly behind the turtle**, at the same height.
4. Put a stack of coal or charcoal in the **first slot of the chest**. Leave room for the items it brings back.

**Length goes forward. Width goes to the turtle's right. Depth goes down from its starting block.** The column directly below the turtle is included in the mining area.

Keep the starting chest in place. Keep other matching chests away from the mining area: the turtle uses this chest to find its way home after an interrupted move.

## 3. Start mining

Type:

```text
mole
```

The turtle asks:

```text
Length in blocks [16]:
Width in blocks [16]:
Depth below the turtle [64]:
```

Press **Enter** to use the number in brackets, or type a different whole number. Type `q` to cancel setup.

For your first test, choose **3**, **3**, and **6**. Check that the chest is behind the turtle, then press Enter at the final prompt to start.

Mole saves its starting position and creates an automatic restart file. Your settings and progress are saved for the next time it runs.

If you already use your own startup program, the miner keeps it. To make that existing program resume mining, add `shell.run("mole")` to it.

## What will it dig?

The turtle makes **one-block-high tunnels**, normally with **two columns of stone between them**. It connects the tunnels at their ends. The next tunnel level is **three blocks lower**. It also makes an entry shaft below the starting corner.

At every tunnel step it checks the blocks above, below, in front, behind, left, and right. It leaves ordinary trash blocks alone unless it needs to break them to move. If it finds a block that is not on the trash list, it follows connected non-trash blocks to collect the vein. Unknown blocks from mods are kept by default.

**Mole uses tunnel mining.** Stone stays in the walls, ceiling, and floor. Some isolated ores hidden between tunnels can be missed because the turtle cannot see through stone. Connected veins it finds are followed inside the chosen area. A search has size and depth limits so huge modded deposits cannot make the turtle wander forever; some of a very large deposit may remain.

The turtle returns to the chest when its inventory is nearly full, it needs fuel, or a tunnel level is finished. It also comes home when it finishes the whole job. It chooses the shortest route through cells it has already visited, and uses known tunnels to get back to work. If a passage becomes blocked, it tries another known route. If none is clear, it tries to mine the obstruction, then digs a detour toward the starting position. It reconnects to known tunnels as soon as it can. Emergency detours can extend one block past the far edges of the chosen width and length, and can reach the surface. Keep that border clear of builds. Protected blocks and machines are still left alone. If every approach is blocked, fuel is insufficient, or inventory space runs out, it saves progress and reports the problem after attempting to return.

## Everyday controls

| Type this | What happens |
| --- | --- |
| `mole` | Start, resume, or answer the questions for a new turtle |
| `mole status` | Show saved progress, depth, and fuel |
| `mole settings` | Change which blocks count as trash |
| `mole return` | Return to the chest and pause |
| `mole new` | Set up a new job after finishing or returning home |
| `mole help` | Show the short command list |

While the miner is running, hold **Ctrl+T** to stop the program. Then type `mole return` if you want it to go home. Stopping can leave a move unfinished in the save file; automatic chest recovery handles this on the next launch.

Do not pick up, move, or turn the turtle during a saved job. After a job is finished, you can move it to a new starting corner, put the chest behind it, and run `mole new`. If you paused an unfinished job to start a new one, that abandons the old job; its last state is saved as `quarry-data/previous-job` for reference.

## Change the trash list

Run:

```text
mole settings
```

Choose **1** to ignore a block or **2** to keep it. Enter its full Minecraft block ID, such as `minecraft:stone` or a mod's `modname:block_name`. Choose **3** to see the list. Press Enter to finish.

The starter list contains dirt, stone, cobblestone, gravel, granite, and similar common blocks. Ores and unknown modded blocks are not trash by default.

Choose **4** to turn trash dropping on or off. Turning it off keeps tunnel rubble and unloads it into the chest. When dropping is on, the turtle only drops trash into empty space below it; if the floor is solid it keeps that rubble until it gets a safe chance to drop it or unload. Dropped items are normal world items, so they may be picked up again.

An ore's block ID and the item it drops can be different. The block ID controls whether the turtle follows it; the item ID controls whether a collected item is discarded. Add both IDs only if you want both ignored/discarded. Coal and charcoal are kept for fuel even if added to trash.

## If it stops

| Message or problem | What to do |
| --- | --- |
| Not enough fuel | Add coal/charcoal to the chest's first slots, then run `mole` again. |
| Chest full | Empty the chest, then run `mole` again. |
| No chest behind you during setup | Place it directly behind the turtle at the same height, then press Enter to retry. |
| Protected or unbreakable block | Check what it reported. It tries to return home and pauses. Run `mole` after fixing the cause and follow the resume prompt. |
| Starting chest not found during recovery | Check that the original chest is still there and the chunks are loaded. Clear any new blocks from the return tunnels, then retry `mole`. Recovery will not dig while its position is uncertain. |
| Download says file already exists | Follow the update steps below instead of downloading over the existing file. |
| Download says 404 / not found | Check the username, repository name, branch, and filename in the URL. The repository must be public. |
| Downloads are disabled or blocked | Ask the server owner to allow CC: Tweaked HTTP downloads from GitHub's raw file domain. |

Keep the turtle's mining area and chest loaded. The program cannot load chunks itself. The automatic restart file resumes the saved job when the turtle boots; a stopped or paused program may still need you to run `mole`.

## Update Mole

1. Hold Ctrl+T to stop the running program, then run `mole return` and wait for the turtle to reach its chest.
2. Back up the program with `move mole mole-backup`. If that name already exists, choose another, such as `mole-backup-2`.
3. Download the latest version:

```text
wget https://raw.githubusercontent.com/alexrvandijk/quarry-turtle/main/mole.lua mole
```

4. Run `mole` to resume.

### Moving from the old quarry program to Mole

1. Stop the old program with Ctrl+T, then run `quarry return` and wait for the chest.
2. Download Mole using the command above.
3. Run `mole`.

**Keep the `quarry-data` folder.** Mole uses it to keep your saved location and progress. It updates the old automatic restart script when it recognizes one of our scripts. A custom startup script can resume Mole with `shell.run("mole")`.

An unfinished old excavation job switches to tunnel mining at the chest, restarting its current vertical level with the new pattern. A finished job stays finished; use `mole new` to set up the next one.

## For curious players

The turtle saves progress after moves and turns. If a move was interrupted, it tries the possible saved positions and finds its original chest without GPS. It keeps extra fuel for this trip and does not dig while uncertain. Once home, it replays the saved route to continue the vein or tunnel step.

Recovery needs a clear return route, its original chest, and enough fuel. If a movement is interrupted during emergency excavation, Mole must confirm its position before digging again; a blocked recovery route can still need clearing. Matching chest type and size is not a unique identity, which is why the starting chest should be the only matching inventory near the recovery area. Repeated interruptions, changed terrain, or a missing chest can still need help.

More advanced settings live in `quarry-data/config`: allowed fuel items, protected blocks, fuel reserves, retries, and vein search limits. Job dimensions are fixed once a job starts.

The program does not seal liquids or collect lava in buckets. It avoids known protected blocks and detected machine peripherals, but not every modded machine is detectable; keep it away from builds you want to preserve.

## Faster mining in 1.3.1

Mole takes the shortest turn to face a block and starts new scans from its current facing. All six neighboring directions are still checked where they fall inside the mining area. Saved scans and automatic chest recovery support both left and right turns.

Mole skips searching inventory for fuel when it already has enough, and stops counting empty slots once it finds two. It still checks its fuel reserve and available space. Return trips and trips back to work use the shortest available route through recorded tunnels. Every move still checks for obstacles. If it cannot reach its work position, Mole returns home and pauses instead of waiting underground. These routes help avoid new obstacles on return trips; digging a new tunnel can still encounter bedrock or other unbreakable blocks.

## Testing

Mole has passed offline mock tests for setup, tunnel mining, ore veins, returning home, and recovery. Start your Minecraft test with **3 × 3 × 6**.
