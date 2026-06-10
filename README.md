# TowerDefense
Here is a highly precise, system-level Markdown prompt tailored specifically for **Cursor** (or any LLM-powered IDE). It translates the architecture into explicit execution instructions, rules, and behaviors so that the editor can generate the entire fully functioning codebase from scratch without leaving gaps.

Copy and paste everything below directly into Cursor’s Composer (`Cmd + I` or `Ctrl + I`) or Chat panel.

---

# System Specification Prompt: Bloons-Style Tower Defense MVP

## Project Overview

You are building a fully functioning, standalone 2D Tower Defense MVP for iOS/iPadOS built entirely with **SwiftUI** (UI, state tracking, HUD overlays) and **SpriteKit** (game loop, high-performance rendering, movement vectors, and custom collision targeting calculations).

The game must closely mirror *Bloons TD5* mechanisms, featuring automatic grid-free placement, enemy health scaling, and active individual tower special abilities that can be triggered manually by tapping on an active tower.

### Global Constraints & Requirements

* **Zero Placeholders:** Implement every single mathematical calculation, vector update, type definition, and UI view to completion. Do not leave any `// TODO`, `pass`, or mock logic.
* **Asset-Free Design:** Do not assume external `.xcassets` artwork bundles. Every sprite, vehicle, projectile, and map layout must be generated programmatically using native `SKShapeNode` drawing frames or colorized `SKSpriteNode` objects.
* **Target Device Specs:** Hardcode view spaces to a fixed aspect ratio or virtual canvas size of $1024 \times 768$ pixels.

---

## Technical Component Directory

### File 1: `GameConfig.swift`

**Role:** Establish structural data structures, configuration profiles, constants, and coordinate matrices.

* **`EnemyType` Enum:** Must support `red`, `blue`, and `camo` types. Each case must map to hardcoded scalar speeds, point rewards, and structural health layers (e.g., Red takes 1 hit, Blue takes 2 hits, Camo requires 3 hits and is invisible to towers without active camo detection).
* **`TowerType` Enum:** Must support `dartNode` (single target, modest speed), `tackNode` (slower, radial close-range), and `superNode` (ultra-fast, expansive range, costly). Define fixed gold costs, structural ranges, and specific weapon cycle cooldown frequencies.
* **Ability Properties:** Map each `TowerType` to its active ability string signature and an independent cooldown frame delta (e.g., *Dart Monkey* gets an 8-second Camo Vision flare; *Tack Shooter* gets a localized high-damage ring burst; *Super Monkey* flashes the display, instantly dealing massive damage to all onscreen nodes).
* **Global Geometry Path:** Define a static `[CGPoint]` coordinate array sequence mapped perfectly across a $1024 \times 768$ coordinate system to act as the linear waypoint map track for enemies.

### File 2: `GameViewModel.swift`

**Role:** Provide a unified `ObservableObject` acting as the data architecture bridge handling UI updates and balance transactions.

* **Published Metrics:** Expose variables for current player gold balance, surviving heart points/lives, current active monster wave level, active simulation flags, and an optional tracked active placement node type reference (`selectedTowerType`).
* **State Manipulation Logic:**
* Provide safe transaction controls to mutate currency values (returning a boolean flag validating if an asset purchase can clear the balance criteria).
* Implement damage updates to decrease lives; if live values zero out, immediately drop the simulation flag to halt active routines.
* Maintain a structural timestamp index (`[String: Date]`) logging explicit execution dates paired with individual tower ID signatures to prevent ability usage until the specific tower's cooldown window has completely passed.



### File 3: `GameScene.swift`

**Role:** Handle the core graphic workspace inheriting from `SKScene`. This script runs the framework lifecycle update phases ($60\text{Hz}$) to continuously manage movement, orientation tracking, projectile paths, and area-of-effect calculations.

* **Graphic Asset Modeling:** Create internal class extensions for `EnemyNode` and `TowerNode` keeping strict track of internal instance identifiers, color properties matching target status conditions, current sub-destination tracking target indexes, and localized timing records.
* **Initialization Loops:** Render a visible thick underlying track representation mapping to the global config waypoint sequence to display the level map path explicitly.
* **Input Touch Resolution:**
* If a menu item is active (`selectedTowerType != nil`), consume player touch input coordinates to cleanly instantiate a new structural `TowerNode` at that absolute coordinate, deduct its cost, and reset the menu selection state.
* If no menu item is active, scan the coordinate space for any existing intersecting `TowerNode` asset. If a tower is clicked, check the cooldown timers via the view model and trigger its corresponding tactical special ability.


* **Frame Loop Update Phases (`update(_:)`):**
* **Spawning Automation:** Run delta-time tracking to periodically spawn balanced sets of mixed enemy type elements onto the initial path position coordinate.
* **Traversal Routines:** Scan every active enemy element, extracting the coordinate offset pointing directly toward its next sequential waypoint target. Use the following vector transformation formula to move them at their native speed:

$$dx = x_{target} - x_{current}$$


$$dy = y_{target} - y_{current}$$


$$\text{distance} = \sqrt{dx^2 + dy^2}$$


$$\text{movementRatio} = \frac{\text{speed} \times 60 \times \Delta t}{\text{distance}}$$


* **Targeting Cycle Processing:** Evaluate tower reload tracking intervals. If an active tower is ready to attack, find the furthest-progressed valid enemy within its range circular boundary radius. *Enforce strict target checks:* skip `camo` enemies entirely unless the shooting tower has its camo-vision ability actively running.
* **Combat Calculations:** Programmatically launch crisp white geometric projectile nodes from the attacking tower position to the target coordinates. When the projectile collides, apply health reduction. If an enemy node has health remaining but drops to a lower layer, dynamically swap its physical color asset state (e.g., a Blue balloon transitions into a fast Red balloon skin).



### File 4: `ContentView.swift`

**Role:** Declare the multi-layered structural SwiftUI layout framing the primary viewport container.

* **Layout Structure:** Wrap the view within a standard layout stack rendering the interactive `SpriteView(scene:)` canvas directly at the core canvas scale size ($1024 \times 768$).
* **HUD Overlay Panels:**
* **Top Inventory Dashboard Bar:** Display clean modern layout labels displaying player wealth values, current hearts remaining, and active state indicators using high-visibility typography against dark translucent background overlays.
* **Lower Grid Purchase Dock:** Dynamically loop through available `TowerType` catalog entries. Render purchase button cells displaying the title and cost requirements. Safely disable interaction states automatically if the view model balance lacks enough funds to complete the placement transaction.



### File 5: `TowerDefenseApp.swift`

**Role:** Set up the main application entrance framework definition loop wrapper initializing the core `ContentView` within a standardized window grouping structure.

---

## Step-by-Step Execution Plan for Cursor

Execute the generation across the following phase sequence:

1. **Phase 1 (Domain Configurations):** Build `GameConfig.swift` precisely ensuring all raw values, math constants, and waypoint lists match exactly.
2. **Phase 2 (State Pipeline):** Build `GameViewModel.swift` setting up clean transaction functions and dynamic ability verification handlers.
3. **Phase 3 (Simulation Engine):** Implement `GameScene.swift` completely. Ensure the vector tracking math, ray target searches, and programmatic particle bursts are fully implemented without placeholders.
4. **Phase 4 (UI Framework Overlay):** Build `ContentView.swift` and `TowerDefenseApp.swift` to securely bind the underlying scene environment variables to the graphical interface panels.

Here is the **Product Data Model (PDM)** and **Product Definition Matrix** for your Tower Defense application. This maps out how the data structures interact, how the game state changes, and the logical dependencies of the system so Cursor understands the underlying data flow.

---

## 1. Core Product Data Model (Entity Relations)

The game relies on a clean, decoupled data architecture where the visual layer (`SKNode`) simply reflects the underlying state data structures.

```
+-----------------------------------------------------------------+
|                           GameSession                           |
+-----------------------------------------------------------------+
| - id: UUID                                                      |
| - gold: Int                                                     |
| - lives: Int                                                    |
| - currentWave: Int                                              |
| - activeTowers: List<Tower>                                     |
| - activeEnemies: List<Enemy>                                    |
+-------------------------------+---------------------------------+
                                |
        +-----------------------+-----------------------+
        | 1:N                                           | 1:N
+-------v-------+                               +-------v-------+
|     Tower     |                               |     Enemy     |
+---------------+                               +---------------+
| - id: String  |                               | - id: UUID    |
| - type: Enum  |                               | - type: Enum  |
| - position: XY|                               | - health: Int |
| - cooldown: DT|                               | - speed: Float|
| - range: Float|                               | - waypoint:Int|
+-------+-------+                               +---------------+
        | 1:N
+-------v-------+
|  Projectile  |
+---------------+
| - damage: Int |
| - target: Enemy|
| - speed: Float|
+---------------+

```

### Data Dictionary

| Entity | Attribute | Data Type | Description |
| --- | --- | --- | --- |
| **GameSession** | `gold` | `Integer` | Player's balance for purchasing defenses. |
|  | `lives` | `Integer` | Health of the player. Game over occurs at 0. |
| **Tower** | `id` | `String (UUID)` | Unique identifier used to map cooldown timestamps. |
|  | `isCamoDetectionActive` | `Boolean` | State flag altered exclusively by the Dart Monkey ability. |
| **Enemy** | `waypointIndex` | `Integer` | Tracks the current track segment the enemy is traversing. |
|  | `currentHealth` | `Integer` | Determines structural tier degradation (Blue $\rightarrow$ Red). |

---

## 2. State Transition Matrix

The game engine operates under a strict finite state machine (FSM) to ensure UI overlays, inputs, and background calculations don't conflict.

| Current State | Event/Trigger | Action Taken | Next State |
| --- | --- | --- | --- |
| **MainMenu** | User taps "Start Game" | Initialize `GameSession`, load map geometries. | **ActiveGameplay** |
| **ActiveGameplay** | User selects tower menu cell | Highlight cell, activate placement bounding box logic. | **TowerPlacementMode** |
| **TowerPlacementMode** | User taps valid coordinates | Deduct currency, instantiate `TowerNode`, clear selection. | **ActiveGameplay** |
| **TowerPlacementMode** | User taps invalid/insufficient gold | Flash UI error warning, cancel selection. | **ActiveGameplay** |
| **ActiveGameplay** | Enemy exits final waypoint | Deduct 1 unit from `lives`. Check if $\text{lives} \le 0$. | **ActiveGameplay** or **GameOver** |
| **ActiveGameplay** | User taps active tower node | Read ID, evaluate cooldown matrix, execute special action if clear. | **ActiveGameplay** |
| **ActiveGameplay** / **GameOver** | User hits "Reset" | Wipe active entity lists, restore default configurations. | **MainMenu** |

---

## 3. Precedence Diagram Method (PDM) / Implementation Dependency Map

When tracking your development sequence or passing components to Cursor file by file, use this structural dependency logic:

```
[1. GameConfig Data Structures] 
               │
               ▼
[2. GameViewModel State Bridge]
               │
               ▼
[3. GameScene Graphics & Math Logic] ◄─── [Map Track Waypoints Layout]
               │
               ▼
[4. ContentView SwiftUI HUD Canvas]
               │
               ▼
[5. App Lifecycle Entry Manifest]

```

* **Task 1 (GameConfig):** Must be compiled first. No logic depends on UI, but all downstream files depend on these data primitives.
* **Task 2 (GameViewModel):** Manages the reactive pipeline data binds. Completely decoupled from rendering loops.
* **Task 3 (GameScene):** Imports vectors, handles spatial geometry, triggers soundless visual effects, and feeds score deltas back into Task 2.
* **Task 4 (ContentView):** Wraps Task 3 inside a viewport container layer, binding interface interactors to Task 2 properties.
