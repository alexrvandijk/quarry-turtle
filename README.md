# Quarry Turtle 1.2

**A little mining robot that digs tunnels, finds nearby ores, and brings them back to your chest.**

Run `quarry`, answer three questions, and it handles the rest. You do not need to edit code or run a separate setup command.

## What you need

- Minecraft with **CC: Tweaked**.
- A **mining turtle** with a diamond pickaxe upgrade. A normal or advanced mining turtle works.
- A chest and some coal or charcoal. Put one stack in the chest to start.
- Internet downloads enabled for turtles. If your server blocks them, ask its owner.

You do **not** need a wireless modem, GPS computers, or another download account.

## 1. Put the files on GitHub

If you already have the `quarry-turtle` repository from the earlier guide, open it and upload the new files there. Keep the same filenames so the download command stays the same.

Otherwise:

1. Sign in to GitHub and open **https://github.com/new**.
2. Name your repository **quarry-turtle**. A repository is the folder for your project on GitHub.
3. Choose **Public**. This lets the turtle download the program without signing in.
4. Turn on **Add a README**, then click **Create repository**.
5. Extract this download's ZIP on your computer. Open the folder inside it.
6. On GitHub, choose **Add file → Upload files**.
7. Drag in **quarry.lua** and **README.md**. Upload these files themselves, not the ZIP or the whole folder. They should appear on the repository's main page.
8. Click **Commit changes** to save them. Choose the main branch if GitHub asks.

Only `quarry.lua` is needed by the turtle. `startup.lua` is an optional spare copy of the automatic restart script; `test.lua` is for testing the code outside Minecraft.

## 2. Download the program onto your turtle

Right-click the mining turtle to open its screen. Type this command and press Enter:

```text
wget https://raw.githubusercontent.com/YOUR_USERNAME/quarry-turtle/main/quarry.lua quarry
```

Replace **YOUR_USERNAME** with your GitHub username. If your username were `SteveMiner`, you would type:

```text
wget https://raw.githubusercontent.com/SteveMiner/quarry-turtle/main/quarry.lua quarry
```

This saves the program on the turtle with the short name **quarry**. These commands assume your GitHub branch is called `main`.

## 3. Place the turtle and chest

1. Choose an area you are happy for the turtle to mine underneath.
2. Put the turtle at the **near-left corner**, facing into the area.
3. Put the chest **directly behind the turtle**, at the same height.
4. Put a stack of coal or charcoal in the **first slot of the chest**. Leave room for the items it brings back.

**Length goes forward. Width goes to the turtle's right. Depth goes down from its starting block.** The column directly below the turtle is included in the mining area.

Keep the starting chest in place. Keep other matching chests away from the mining area: the turtle uses this chest to find its way home after an interrupted move.

## 4. Start mining

Type:

```text
quarry
```

The turtle asks:

```text
Length in blocks [16]:
Width in blocks [16]:
Depth below the turtle [64]:
```

Press **Enter** to use the number in brackets, or type a different whole number. Type `q` to cancel setup.

For your first test, choose **3**, **3**, and **6**. Check that the chest is behind the turtle, then press Enter at the final prompt to start.

That is all! The turtle saves the starting position automatically. It also creates its automatic restart file if you do not already have one. You do not need `quarry init`, a separate startup download, or a configuration editor.

If you already use your own startup program, the miner keeps it. To make that existing program resume mining, add `shell.run("quarry")` to it.

## What will it dig?

The turtle makes **one-block-high tunnels**, normally with **two columns of stone between them**. It connects the tunnels at their ends. The next tunnel level is **three blocks lower**. It also makes an entry shaft below the starting corner.

At every tunnel step it checks the blocks above, below, in front, behind, left, and right. It leaves ordinary trash blocks alone unless it needs to break them to move. If it finds a block that is not on the trash list, it follows connected non-trash blocks to collect the vein. Unknown blocks from mods are kept by default.

**This is tunnel mining, not an empty pit.** Stone stays in the walls, ceiling, and floor. Some isolated ores hidden between tunnels can be missed because the turtle cannot see through stone. Connected veins it finds are followed inside the chosen area. A search has size and depth limits so huge modded deposits cannot make the turtle wander forever; some of a very large deposit may remain.

The turtle returns to the chest when its inventory is nearly full, it needs fuel, or a tunnel level is finished. It also comes home when it finishes the whole job.

## Everyday controls

| Type this | What happens |
| --- | --- |
| `quarry` | Start, resume, or answer the questions for a new turtle |
| `quarry status` | Show saved progress, depth, and fuel |
| `quarry settings` | Change which blocks count as trash |
| `quarry return` | Return to the chest and pause |
| `quarry new` | Set up a new job after finishing or returning home |
| `quarry help` | Show the short command list |

While the miner is running, hold **Ctrl+T** to stop the program. Then type `quarry return` if you want it to go home. Stopping can leave a move unfinished in the save file; automatic chest recovery handles this on the next launch.

Do not pick up, move, or turn the turtle during a saved job. After a job is finished, you can move it to a new starting corner, put the chest behind it, and run `quarry new`. If you paused an unfinished job to start a new one, that abandons the old job; its last state is saved as `quarry-data/previous-job` for reference.

## Change the trash list

Run:

```text
quarry settings
```

Choose **1** to ignore a block or **2** to keep it. Enter its full Minecraft block ID, such as `minecraft:stone` or a mod's `modname:block_name`. Choose **3** to see the list. Press Enter to finish.

The starter list contains dirt, stone, cobblestone, gravel, granite, and similar common blocks. Ores and unknown modded blocks are not trash by default.

Choose **4** to turn trash dropping on or off. Turning it off keeps tunnel rubble and unloads it into the chest. When dropping is on, the turtle only drops trash into empty space below it; if the floor is solid it keeps that rubble until it gets a safe chance to drop it or unload. Dropped items are normal world items, so they may be picked up again.

An ore's block ID and the item it drops can be different. The block ID controls whether the turtle follows it; the item ID controls whether a collected item is discarded. Add both IDs only if you want both ignored/discarded. Coal and charcoal are kept for fuel even if added to trash.

## If it stops

| Message or problem | What to do |
| --- | --- |
| Not enough fuel | Add coal/charcoal to the chest's first slots, then run `quarry` again. |
| Chest full | Empty the chest, then run `quarry` again. |
| No chest behind you during setup | Place it directly behind the turtle at the same height, then press Enter to retry. |
| Protected or unbreakable block | Check what it reported. It tries to return home and pauses. Run `quarry` after fixing the cause and follow the resume prompt. |
| Starting chest not found during recovery | Check that the original chest is still there and the chunks are loaded. Clear any new blocks from the return tunnels, then retry `quarry`. Recovery will not dig while its position is uncertain. |
| Download says file already exists | Follow the update steps below instead of downloading over the existing file. |
| Download says 404 / not found | Check the username, repository name, branch, and filename in the URL. The repository must be public. |
| Downloads are disabled or blocked | Ask the server owner to allow CC: Tweaked HTTP downloads from GitHub's raw file domain. |

Keep the turtle's mining area and chest loaded. The program cannot load chunks itself. The automatic restart file resumes the saved job when the turtle boots; a stopped or paused program may still need you to run `quarry`.

## Update from an earlier version

1. Stop the running program with Ctrl+T.
2. Run `quarry return` and wait until it reaches its chest. If recovery starts, let that finish first.
3. Upload the new **quarry.lua** and **README.md** to your existing GitHub repository.
4. On the turtle, back up the old program:

```text
move quarry quarry-backup-1.1
```

If that backup name already exists, use another name, such as `quarry-backup-2`.

5. Download the updated program:

```text
wget https://raw.githubusercontent.com/YOUR_USERNAME/quarry-turtle/main/quarry.lua quarry
```

6. Run `quarry`.

**Keep the `quarry-data` folder.** It contains the turtle's saved location and progress. Do not initialize again or delete it to update.

An unfinished old excavation job changes to tunnel mining at the starting chest. It restarts the old job's current vertical level with the new tunnel pattern, keeping the original size and depth. Previously cleared space cannot be filled back in. A finished job stays finished; use `quarry new` for your next test.

## For curious players

The turtle saves progress after moves and turns. If a move was interrupted, it tries the possible saved positions and finds its original chest without GPS. It keeps extra fuel for this trip and does not dig while uncertain. Once home, it replays the saved route to continue the vein or tunnel step.

Recovery needs a clear return route, its original chest, and enough fuel. Matching chest type and size is not a unique identity, which is why the starting chest should be the only matching inventory near the recovery area. Repeated interruptions, changed terrain, or a missing chest can still need help.

More advanced settings live in `quarry-data/config`: allowed fuel items, protected blocks, fuel reserves, retries, and vein search limits. You do not need to edit that file for normal play. Job dimensions are fixed once a job starts.

The program does not seal liquids or collect lava in buckets. It avoids known protected blocks and detected machine peripherals, but not every modded machine is detectable; keep it away from builds you want to preserve.

## Testing

The previous version has worked in the user's Minecraft test. This new tunnel version has passed 592 offline mock scenarios for setup, veins, leaving trash and hidden ores alone, returns, recovery, and upgrades. It still needs a fresh Minecraft test—start with **3 × 3 × 6**.
