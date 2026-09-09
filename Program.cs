using System;
using Lifestate;

var clock = new GameClock();
var player = new PlayerState(clock);

Console.WriteLine("--- LIFESTATE Age System Test ---");
Console.WriteLine($"New Game - {clock}");
Console.WriteLine($"Player Age: {player.Age}");

// Test: Advance 365 days
// 365 days * 24 hours * 60 minutes = 525,600 in-game minutes
// 525,600 / 4 (minutes/sec) = 131,400 real seconds
int secondsToAdvance = 131400;
clock.AdvanceSeconds(secondsToAdvance);

Console.WriteLine($"\nSimulating 365 days passing ({secondsToAdvance} real seconds)...");
Console.WriteLine($"Current Time: {clock}");
Console.WriteLine($"Player Age: {player.Age}");
