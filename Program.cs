using System;
using Lifestate;

Console.WriteLine("--- LIFESTATE Life Stage Test ---");

int[] targetAges = { 0, 2, 6, 13, 18, 65 };

foreach (int age in targetAges)
{
    var clock = new GameClock();
    var player = new PlayerState(clock);

    // Calculate seconds needed to reach this age
    // 360 real seconds per in-game day
    int daysNeeded = age * 365;
    int secondsToAdvance = daysNeeded * 360;

    clock.AdvanceSeconds(secondsToAdvance);

    Console.WriteLine($"Age {player.Age} -> LifeStage {player.LifeStage}");
}
