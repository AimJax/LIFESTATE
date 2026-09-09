using System;
using Lifestate;

Console.WriteLine("--- LIFESTATE Energy Drain Test ---");

var clock = new GameClock();
var player = new PlayerState(clock);

// 1. New player -> Energy 100
Console.WriteLine($"Start: Energy {player.Energy}");

// 2. Pass 30 game minutes -> Energy 100
// 30 in-game minutes = 7.5 seconds, but AdvanceSeconds takes int.
// Let's use 8 seconds = 32 minutes or just pass minutes to a wrapper.
// Actually, I'll just call player.UpdateEnergy(30) directly for precise testing as requested.

Console.WriteLine("\nPassing 30 game minutes...");
player.UpdateEnergy(30);
Console.WriteLine($"Energy: {player.Energy} (Expected: 100)");

// 3. Pass another 30 game minutes -> Energy 99
Console.WriteLine("Passing another 30 game minutes...");
player.UpdateEnergy(30);
Console.WriteLine($"Energy: {player.Energy} (Expected: 99)");

// 4. Pass another 9 game hours -> Energy 90
Console.WriteLine("Passing another 9 game hours (540 minutes)...");
player.UpdateEnergy(540);
Console.WriteLine($"Energy: {player.Energy} (Expected: 90)");

// 5. Pass enough additional time -> Energy 0
Console.WriteLine("Passing another 100 game hours (6000 minutes)...");
player.UpdateEnergy(6000);
Console.WriteLine($"Energy: {player.Energy} (Expected: 0)");

// 6. Energy must never become negative
Console.WriteLine("Passing another 10 game hours...");
player.UpdateEnergy(600);
Console.WriteLine($"Energy: {player.Energy} (Expected: 0)");
