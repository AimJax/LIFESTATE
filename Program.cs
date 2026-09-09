using System;
using Lifestate;

int[] testDays = { 0, 364, 365, 730 };

Console.WriteLine("--- LIFESTATE Calendar Test ---");

foreach (int day in testDays)
{
    var clock = new GameClock();

    // 1 real second = 4 in-game minutes, so 360 real seconds = 1 in-game day.
    clock.AdvanceSeconds(day * 360);

    Console.WriteLine($"Day {day} -> Year {clock.Year}, DayOfYear {clock.DayOfYear}");
}
