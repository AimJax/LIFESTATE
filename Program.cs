using System;
using Lifestate;

Console.WriteLine("--- LIFESTATE Sleep & Energy Recovery Test ---");

var clock = new GameClock();
var player = new PlayerState(clock);

// 1. New player -> Energy 100, IsSleeping = false
Console.WriteLine($"1. Start: Energy {player.Energy}, IsSleeping {player.IsSleeping} (Expected: 100, False)");

// 2. Awake Energy drain (120 mins = -2 Energy)
Console.WriteLine("\nPassing 120 minutes awake...");
player.UpdateEnergy(120);
Console.WriteLine($"2. Energy: {player.Energy} (Expected: 98)");

// 3. Start sleeping
player.StartSleeping();
Console.WriteLine($"3. Start sleeping: IsSleeping {player.IsSleeping} (Expected: True)");

// 4. Partial sleep (30 mins sleep = +0 energy recovered, rate is +5/hr)
Console.WriteLine("\nPassing 30 minutes sleep...");
player.UpdateEnergy(30);
Console.WriteLine($"4. Energy: {player.Energy} (Expected: 98)");

// 5. Another 30 minutes (Total 60 mins sleep = +5 Energy)
Console.WriteLine("Passing another 30 minutes sleep...");
player.UpdateEnergy(30);
Console.WriteLine($"5. Energy: {player.Energy} (Expected: 100)");

// 6. Test 8 hours of sleep from a low Energy value (20 Energy)
Console.WriteLine("\nResetting to Energy 20...");
// Hack to reset energy for test:
// Create a new player state (the clock continues, but energy is reset)
player = new PlayerState(clock); 
// Force energy to 20
typeof(PlayerState).GetProperty("Energy")!.SetValue(player, 20);

player.StartSleeping();
Console.WriteLine($"Sleeping from Energy {player.Energy} for 8 hours (480 mins)...");
player.UpdateEnergy(480);
Console.WriteLine($"6. Energy: {player.Energy} (Expected: 60)");

// 7. Continue sleeping at Energy 100
player.UpdateEnergy(60); // Already 60, but test if it caps at 100
player.UpdateEnergy(1000); // Massive sleep
Console.WriteLine($"7. Continued sleep: Energy {player.Energy} (Expected: 100)");

// 8. Stop sleeping
player.StopSleeping();
Console.WriteLine($"8. Stop sleeping: IsSleeping {player.IsSleeping} (Expected: False)");

// 9. Resume awake time
Console.WriteLine("\nPassing 60 minutes awake...");
player.UpdateEnergy(60);
Console.WriteLine($"9. Energy: {player.Energy} (Expected: 99)");

// 10. State-switch test
// Start: 100 Energy.
// Awake 30 mins: (Accumulator = 30. Energy = 100 - 0 = 100)
// Sleep 30 mins: (Accumulator = 30. No Energy gain yet. Energy = 100)
Console.WriteLine("\n10. State-switch test...");
player = new PlayerState(clock); // Reset player state
player.UpdateEnergy(30); // Awake 30
player.StartSleeping();
player.UpdateEnergy(30); // Sleep 30
Console.WriteLine($"Energy: {player.Energy} (Expected: 100)");
player.StopSleeping();
Console.WriteLine($"IsSleeping: {player.IsSleeping} (Expected: False)");
