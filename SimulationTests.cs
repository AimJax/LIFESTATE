using System;
using Lifestate;

namespace Lifestate;

public static class SimulationTests
{
    public static void RunTests()
    {
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

        // 11. Eating Tests
        Console.WriteLine("\n--- LIFESTATE Eating Tests ---");
        player = new PlayerState(clock); // Reset

        // 1. New player -> Hunger 100
        Console.WriteLine($"1. Start: Hunger {player.Hunger} (Expected: 100)");

        // 2. Drain to 80
        player.UpdateHunger(20 * 60); // 20 hours drain
        Console.WriteLine($"2. Drain to 80: Hunger {player.Hunger} (Expected: 80)");

        // 3. Eat 10
        player.Eat(10);
        Console.WriteLine($"3. Eat(10): Hunger {player.Hunger} (Expected: 90)");

        // 4. Eat 20 -> 100
        player.Eat(20);
        Console.WriteLine($"4. Eat(20): Hunger {player.Hunger} (Expected: 100)");

        // 5. Eat 50 -> 100 (clamp)
        player.Eat(50);
        Console.WriteLine($"5. Eat(50): Hunger {player.Hunger} (Expected: 100)");

        // 6. Drain
        player.UpdateHunger(60);
        Console.WriteLine($"6. Drain: Hunger {player.Hunger} (Expected: 99)");

        // 7. Eat 0
        player.Eat(0);
        Console.WriteLine($"7. Eat(0): Hunger {player.Hunger} (Expected: 99)");

        // 8. Eat -10
        player.Eat(-10);
        Console.WriteLine($"8. Eat(-10): Hunger {player.Hunger} (Expected: 99)");

        // 9. Confirm Energy/Sleeping unchanged
        Console.WriteLine($"9. Energy: {player.Energy}, IsSleeping: {player.IsSleeping} (Expected: 100, False)");
    }
}
