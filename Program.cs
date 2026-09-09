using System;
using Lifestate;

var player = new PlayerState();
var clock = new GameClock();

Console.WriteLine($"Age: {player.Age}");
Console.WriteLine($"Money: {player.Money}");
Console.WriteLine($"Energy: {player.Energy}");

Console.WriteLine("--- Game Clock Test ---");
Console.WriteLine($"Start:  {clock}");

for (int i = 0; i < 15; i++)
{
    clock.AdvanceSeconds(1);
}

Console.WriteLine($"After 15s: {clock}"); // Expected: Day 0, 01:00
