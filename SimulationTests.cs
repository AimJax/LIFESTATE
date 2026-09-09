using System;
using Lifestate;

namespace Lifestate;

public static class SimulationTests
{
    public static void RunTests()
    {
        Console.WriteLine("--- LIFESTATE Energy & Sleep Regression Tests ---");

        var energyClock = new GameClock();
        var energyPlayer = new PlayerState(energyClock);
        Console.WriteLine($"1. New player: Energy {energyPlayer.Energy} (Expected: 100), IsSleeping {energyPlayer.IsSleeping} (Expected: False)");

        energyPlayer.UpdateEnergy(30);
        Console.WriteLine($"2. Awake 30 minutes: Energy {energyPlayer.Energy} (Expected: 100)");
        energyPlayer.UpdateEnergy(30);
        Console.WriteLine($"3. Another 30 minutes awake: Energy {energyPlayer.Energy} (Expected: 99)");

        var smallClock = new GameClock();
        var smallEnergyPlayer = new PlayerState(smallClock);
        for (int i = 0; i < 60; i++)
        {
            smallEnergyPlayer.UpdateEnergy(1);
        }

        var largeClock = new GameClock();
        var largeEnergyPlayer = new PlayerState(largeClock);
        largeEnergyPlayer.UpdateEnergy(60);
        Console.WriteLine($"4. Repeated small awake updates: Energy {smallEnergyPlayer.Energy} (Expected: 99); one 60-minute update: Energy {largeEnergyPlayer.Energy} (Expected: 99); Equal: {smallEnergyPlayer.Energy == largeEnergyPlayer.Energy} (Expected: True)");

        var sleepClock = new GameClock();
        var sleepPlayer = new PlayerState(sleepClock);
        sleepPlayer.UpdateEnergy(20 * 60); // Drain to 80 so recovery is visible.
        sleepPlayer.StartSleeping();
        Console.WriteLine($"5. Start sleeping: IsSleeping {sleepPlayer.IsSleeping} (Expected: True)");
        sleepPlayer.UpdateEnergy(30);
        Console.WriteLine($"6. Sleep 30 minutes: Energy {sleepPlayer.Energy} (Expected: 80)");
        sleepPlayer.UpdateEnergy(30);
        Console.WriteLine($"7. Another 30 minutes sleeping: Energy {sleepPlayer.Energy} (Expected: 85)");

        var eightHourClock = new GameClock();
        var eightHourPlayer = new PlayerState(eightHourClock);
        eightHourPlayer.UpdateEnergy(50 * 60); // Drain to 50 so +40 is visible.
        eightHourPlayer.StartSleeping();
        eightHourPlayer.UpdateEnergy(480);
        Console.WriteLine($"8. Eight-hour sleep from Energy 50: Energy {eightHourPlayer.Energy} (Expected: 90; +40 before clamp)");
        eightHourPlayer.UpdateEnergy(480);
        Console.WriteLine($"9. Energy upper clamp after 8-hour sleep: Energy {eightHourPlayer.Energy} (Expected: 100)");
        eightHourPlayer.StopSleeping();
        Console.WriteLine($"10. Stop sleeping: IsSleeping {eightHourPlayer.IsSleeping} (Expected: False)");

        var lowerClock = new GameClock();
        var lowerEnergyPlayer = new PlayerState(lowerClock);
        lowerEnergyPlayer.UpdateEnergy(100 * 60);
        Console.WriteLine($"11. Awake Energy lower clamp: Energy {lowerEnergyPlayer.Energy} (Expected: 0)");
        lowerEnergyPlayer.UpdateEnergy(60);
        Console.WriteLine($"12. Additional awake time at zero: Energy {lowerEnergyPlayer.Energy} (Expected: 0)");

        var partialClock = new GameClock();
        var partialEnergyPlayer = new PlayerState(partialClock);
        partialEnergyPlayer.UpdateEnergy(30);
        partialEnergyPlayer.StartSleeping();
        partialEnergyPlayer.UpdateEnergy(30);
        Console.WriteLine($"13. Awake 30 then sleeping 30 (separate partial accumulators): Energy {partialEnergyPlayer.Energy} (Expected: 100), IsSleeping {partialEnergyPlayer.IsSleeping} (Expected: True)");
        partialEnergyPlayer.StopSleeping();
        partialEnergyPlayer.UpdateEnergy(30);
        Console.WriteLine($"14. Resume awake 30 (awake partial completes): Energy {partialEnergyPlayer.Energy} (Expected: 99)");
        partialEnergyPlayer.StartSleeping();
        partialEnergyPlayer.UpdateEnergy(30);
        Console.WriteLine($"15. Resume sleeping 30 (sleep partial completes): Energy {partialEnergyPlayer.Energy} (Expected: 100)");
        partialEnergyPlayer.StopSleeping();
        Console.WriteLine($"16. Final state: IsSleeping {partialEnergyPlayer.IsSleeping} (Expected: False)");

        Console.WriteLine("\n--- LIFESTATE Hunger Drain Test ---");

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
