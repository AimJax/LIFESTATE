using System;
using Lifestate;

Console.WriteLine("--- LIFESTATE Hunger Drain Test ---");

var clock = new GameClock();
var player = new PlayerState(clock);

// 1. New player -> Hunger 100
Console.WriteLine($"1. Start: Hunger {player.Hunger} (Expected: 100)");

// 2. Pass 30 minutes: Hunger 100
Console.WriteLine("\nPassing 30 minutes...");
player.UpdateHunger(30);
Console.WriteLine($"2. Hunger: {player.Hunger} (Expected: 100)");

// 3. Pass another 30 minutes: Hunger 99
Console.WriteLine("Passing another 30 minutes...");
player.UpdateHunger(30);
Console.WriteLine($"3. Hunger: {player.Hunger} (Expected: 99)");

// 4. Pass another 9 hours (540 mins): Hunger 90
Console.WriteLine("Passing another 9 hours (540 minutes)...");
player.UpdateHunger(540);
Console.WriteLine($"4. Hunger: {player.Hunger} (Expected: 90)");

// 5. Start sleeping
player.StartSleeping();
Console.WriteLine("Start sleeping...");

// 6. Sleep for 8 hours (480 mins): Hunger 82
Console.WriteLine("Passing 8 hours (480 minutes) sleep...");
player.UpdateHunger(480);
Console.WriteLine($"6. Hunger: {player.Hunger} (Expected: 82)");

// 7. Stop sleeping
player.StopSleeping();
Console.WriteLine("Stop sleeping...");

// 8. Pass enough additional time -> Hunger 0
// Remaining hunger: 82. Need 82 hours = 4920 minutes.
Console.WriteLine("Passing 4920 minutes (82 hours)...");
player.UpdateHunger(4920);
Console.WriteLine($"8. Hunger: {player.Hunger} (Expected: 0)");

// 9. Pass more time: Hunger 0
Console.WriteLine("Passing another 60 minutes...");
player.UpdateHunger(60);
Console.WriteLine($"9. Hunger: {player.Hunger} (Expected: 0)");

// 10. Verify repeated small updates
// 60 x 1 minute = 1 hour (-1 Hunger)
Console.WriteLine("\n10. Testing repeated small updates (60 * 1 min)...");
player = new PlayerState(clock); // Reset hunger to 100
for (int i = 0; i < 60; i++)
{
    player.UpdateHunger(1);
}
Console.WriteLine($"Hunger (60 * 1 min): {player.Hunger} (Expected: 99)");
