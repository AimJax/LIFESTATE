using System;
using Lifestate;

Console.WriteLine("--- LIFESTATE Sleep & Energy Recovery Test ---");

var clock = new GameClock();
var player = new PlayerState(clock);

// 1. New player -> Energy 100, IsSleeping = false
Console.WriteLine($"1. Start: Energy {player.Energy}, IsSleeping {player.IsSleeping} (Expected: 100, False)");

// 2. Awake Energy drain
Console.WriteLine("\nPassing 120 minutes awake...");
player.UpdateEnergy(120);
Console.WriteLine($"2. Energy: {player.Energy} (Expected: 98)");

// 3. Start sleeping
player.StartSleeping();
Console.WriteLine($"3. Start sleeping: IsSleeping {player.IsSleeping} (Expected: True)");

// 4. Partial sleep (3 mins sleep = 0 energy recovered)
Console.WriteLine("\nPassing 3 minutes sleep...");
player.UpdateEnergy(3);
Console.WriteLine($"4. Energy: {player.Energy} (Expected: 98)");

// 5. Eight-hour sleep (480 mins sleep = +96 energy, but clamped to 100)
// Current energy 98. 98 + 96 = 194 -> Clamped to 100.
Console.WriteLine("Passing 480 minutes sleep...");
player.UpdateEnergy(480);
Console.WriteLine($"5. Energy: {player.Energy} (Expected: 100)");

// 6. Continue sleeping at Energy 100
Console.WriteLine("Passing 60 minutes sleep...");
player.UpdateEnergy(60);
Console.WriteLine($"6. Energy: {player.Energy} (Expected: 100)");

// 7. Stop sleeping
player.StopSleeping();
Console.WriteLine($"7. Stop sleeping: IsSleeping {player.IsSleeping} (Expected: False)");

// 8. Resume awake time
Console.WriteLine("\nPassing 60 minutes awake...");
player.UpdateEnergy(60);
Console.WriteLine($"8. Energy: {player.Energy} (Expected: 99)");

// 9. State-switch test
// Start: 99 Energy.
// Awake 30 mins: (Accumulator = 60 + 30 = 90. Energy = 99 - 1 = 98)
// Sleep 30 mins: (Accumulator = 0 + 30 = 30. Recover +6. Energy = 98 + 6 = 100)
Console.WriteLine("\n9. State-switch test...");
player.UpdateEnergy(30); // Awake 30
player.StartSleeping();
player.UpdateEnergy(30); // Sleep 30
Console.WriteLine($"Energy: {player.Energy} (Expected: 100)");
player.StopSleeping();
Console.WriteLine($"IsSleeping: {player.IsSleeping} (Expected: False)");
