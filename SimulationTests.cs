using System;
using Lifestate;

namespace Lifestate;

public static class SimulationTests
{
    public static void RunTests()
    {
        Console.WriteLine("--- LIFESTATE Energy & Sleep Regression Tests ---");
        Console.WriteLine("STARTING TESTS");

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

        // --- NEW THIRST TESTS ---
        Console.WriteLine("\n--- LIFESTATE Thirst & Drinking Tests ---");
        var tClock = new GameClock();
        var tPlayer = new PlayerState(tClock);

        // 1. New player -> Thirst 100
        Console.WriteLine($"1. Start: Thirst {tPlayer.Thirst} (Expected: 100)");

        // 2. +30 minutes
        tPlayer.UpdateThirst(30);
        Console.WriteLine($"2. +30 minutes: Thirst {tPlayer.Thirst} (Expected: 100)");

        // 3. +30 minutes (Total 60)
        tPlayer.UpdateThirst(30);
        Console.WriteLine($"3. +30 minutes: Thirst {tPlayer.Thirst} (Expected: 98)");

        // 4. +1 hour
        tPlayer.UpdateThirst(60);
        Console.WriteLine($"4. +1 hour: Thirst {tPlayer.Thirst} (Expected: 96)");

        // 5. Repeated small updates
        tPlayer = new PlayerState(tClock);
        for (int i = 0; i < 60; i++) tPlayer.UpdateThirst(1);
        var tPlayer2 = new PlayerState(tClock);
        tPlayer2.UpdateThirst(60);
        Console.WriteLine($"5. Repeated small updates equals 60-min update: {tPlayer.Thirst == tPlayer2.Thirst} (Expected: True)");

        // 6. Clamp at 0
        tPlayer = new PlayerState(tClock);
        tPlayer.UpdateThirst(50 * 60); // 50 hours * -2 = 100 drain
        Console.WriteLine($"6. Clamp at 0: Thirst {tPlayer.Thirst} (Expected: 0)");

        // 7. More time at 0
        tPlayer.UpdateThirst(60);
        Console.WriteLine($"7. Still 0: Thirst {tPlayer.Thirst} (Expected: 0)");

        // 8. Decrease during sleep
        tPlayer = new PlayerState(tClock);
        tPlayer.StartSleeping();
        tPlayer.UpdateThirst(480); // 8 hours * -2 = 16 drain
        Console.WriteLine($"8. Decrease during sleep: Thirst {tPlayer.Thirst} (Expected: 84)");

        // 9. Drink tests
        tPlayer.Drink(20);
        Console.WriteLine($"9. Drink(20): Thirst {tPlayer.Thirst} (Expected: 100)"); // 84+20 = 104, clamped to 100
        tPlayer.UpdateThirst(60); // 100 -> 98
        tPlayer.Drink(20); // 98+20 = 118, clamped to 100
        Console.WriteLine($"10. Clamp at 100: Thirst {tPlayer.Thirst} (Expected: 100)");
        tPlayer.Drink(0);
        Console.WriteLine($"11. Drink(0): Thirst {tPlayer.Thirst} (Expected: 100)");
        tPlayer.Drink(-10);
        Console.WriteLine($"12. Drink(-10): Thirst {tPlayer.Thirst} (Expected: 100)");

        // 13. Does not affect other stats
        tPlayer.Drink(20);
        Console.WriteLine($"13. Drinking unchanged: Energy {tPlayer.Energy}, Hunger {tPlayer.Hunger}, IsSleeping {tPlayer.IsSleeping} (Expected: 100, 100, True)");
        // Note: Clock advance was not tested directly but by passing time, and Drink() does not call Update...
        // We can verify GameClock simply doesn't advance when calling Drink.
        // Actually, Drink doesn't take clock, it's fine.
        // 14. Non-clamped restoration (70 -> 90)
        tPlayer = new PlayerState(tClock);
        tPlayer.UpdateThirst(15 * 60); // 15 hours * -2 = 30 drain (Thirst 70)
        tPlayer.Drink(20);
        Console.WriteLine($"14. Non-clamped Drink(20): Thirst {tPlayer.Thirst} (Expected: 90)");

        // 15. Verify Drink does not advance GameClock
        var clockCheck = new GameClock();
        var playerCheck = new PlayerState(clockCheck);
        var startDay = clockCheck.Day;
        var startHour = clockCheck.Hour;
        var startMinute = clockCheck.Minute;
        playerCheck.Drink(20);
        bool clockChanged = (clockCheck.Day != startDay || clockCheck.Hour != startHour || clockCheck.Minute != startMinute);
        Console.WriteLine($"15. Drink(20) does not advance GameClock: {!clockChanged} (Expected: True)");


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


        // 12. Automatic Progression Tests
        Console.WriteLine("\n--- LIFESTATE Automatic Progression Tests ---");
        var autoClock = new GameClock();
        var autoPlayer = new PlayerState(autoClock);

        // Helper to run steps
        void RunAutoSteps(int steps)
        {
            for (int i = 0; i < steps; i++)
            {
                autoClock.AdvanceSeconds(1);
                autoPlayer.AdvanceSimulation(4);
            }
        }

        // Test 1: 15 steps = 1 hour (-1 Energy, -1 Hunger, -2 Thirst)
        RunAutoSteps(15);
        Console.WriteLine($"1. 15 steps (60m): Time {autoClock.Hour:00}:{autoClock.Minute:00}, Energy {autoPlayer.Energy}, Hunger {autoPlayer.Hunger}, Thirst {autoPlayer.Thirst} (Expected: 01:00, 99, 99, 98)");

        // Test 2: Partial accumulation
        autoClock = new GameClock();
        autoPlayer = new PlayerState(autoClock);
        RunAutoSteps(14); // 14 steps * 4 = 56 mins
        Console.WriteLine($"2a. 14 steps: Time {autoClock.Hour:00}:{autoClock.Minute:00}, Energy {autoPlayer.Energy}, Hunger {autoPlayer.Hunger}, Thirst {autoPlayer.Thirst} (Expected: 00:56, 100, 100, 100)");
        RunAutoSteps(1); // 15th step
        Console.WriteLine($"2b. 15th step: Time {autoClock.Hour:00}:{autoClock.Minute:00}, Energy {autoPlayer.Energy}, Hunger {autoPlayer.Hunger}, Thirst {autoPlayer.Thirst} (Expected: 01:00, 99, 99, 98)");

        // Test 3: 30 steps = 2 hours
        autoClock = new GameClock();
        autoPlayer = new PlayerState(autoClock);
        RunAutoSteps(30); // 30 steps * 4 = 120 mins
        Console.WriteLine($"3. 30 steps (120m): Time {autoClock.Hour:00}:{autoClock.Minute:00}, Energy {autoPlayer.Energy}, Hunger {autoPlayer.Hunger}, Thirst {autoPlayer.Thirst} (Expected: 02:00, 98, 98, 96)");

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

        // 13. Continuous Sleeping Tests
        Console.WriteLine("\n--- LIFESTATE Continuous Sleeping Tests ---");
        var sleepTestClock = new GameClock();
        var sleepTestPlayer = new PlayerState(sleepTestClock);

        // Test 1: Enter sleeping state
        Console.WriteLine($"1. Start: IsSleeping {sleepTestPlayer.IsSleeping} (Expected: False)");
        sleepTestPlayer.StartSleeping();
        Console.WriteLine($"2. Started sleeping: IsSleeping {sleepTestPlayer.IsSleeping} (Expected: True)");

        // Test 2: One sleeping hour
        // Start with energy 50 to avoid clamping.
        var awakeClock = new GameClock();
        var awakePlayer = new PlayerState(awakeClock);
        awakePlayer.UpdateEnergy(50 * 60);

        // Now awakePlayer.Energy = 50.
        awakePlayer.StartSleeping();
        awakePlayer.AdvanceSimulation(60); // 1 hour sleep
        Console.WriteLine($"3. One sleeping hour (from Energy 50): Energy {awakePlayer.Energy} (Expected: 55), Hunger {awakePlayer.Hunger} (Expected: 99), Thirst {awakePlayer.Thirst} (Expected: 98), IsSleeping {awakePlayer.IsSleeping} (Expected: True)");

        // Test 3: Eight continuous sleeping hours
        awakePlayer.AdvanceSimulation(480); // 8 hours sleep
        Console.WriteLine($"4. Eight continuous sleeping hours: Energy {awakePlayer.Energy} (Expected: 95; 55 + 40), Hunger {awakePlayer.Hunger} (Expected: 91), Thirst {awakePlayer.Thirst} (Expected: 82), IsSleeping {awakePlayer.IsSleeping} (Expected: True)");

        // Test 4: Wake Up
        int beforeDay = awakeClock.Day;
        int beforeHour = awakeClock.Hour;
        int beforeMinute = awakeClock.Minute;
        int beforeEnergy = awakePlayer.Energy;
        int beforeHunger = awakePlayer.Hunger;
        int beforeThirst = awakePlayer.Thirst;

        awakePlayer.StopSleeping();

        bool clockUnchanged = (beforeDay == awakeClock.Day) && (beforeHour == awakeClock.Hour) && (beforeMinute == awakeClock.Minute);
        bool statsUnchanged = (beforeEnergy == awakePlayer.Energy) && (beforeHunger == awakePlayer.Hunger) && (beforeThirst == awakePlayer.Thirst);

        Console.WriteLine($"Wake Up: IsSleeping {awakePlayer.IsSleeping} (Expected: False)");
        Console.WriteLine($"Clock Unchanged: {clockUnchanged} (Expected: True)");
        Console.WriteLine($"Stats Unchanged: {statsUnchanged} (Expected: True)");

        // Test 6: Paused concept does not alter sleep state
        var pauseClock = new GameClock();
        var pausePlayer = new PlayerState(pauseClock);
        pausePlayer.StartSleeping();
        // Do nothing for simulation
        Console.WriteLine($"6. Paused: IsSleeping {pausePlayer.IsSleeping} (Expected: True), Energy {pausePlayer.Energy} (Expected: 100), Hunger {pausePlayer.Hunger} (Expected: 100), Thirst {pausePlayer.Thirst} (Expected: 100), Time {pauseClock.Hour:00}:{pauseClock.Minute:00} (Expected: 00:00)");

        // --- LIFESTATE Work Tests ---
        Console.WriteLine("\n--- LIFESTATE Work Tests ---");
        var workClock = new GameClock();
        var workPlayer = new PlayerState(workClock);

        // Test 1: Fresh player
        Console.WriteLine($"1. Fresh player: Age {workPlayer.Age} (Expected: 0), IsWorking {workPlayer.IsWorking} (Expected: False)");

        // Test 2: Underage work rejection
        workPlayer.StartWorking();
        Console.WriteLine($"2. Underage work rejection: IsWorking {workPlayer.IsWorking} (Expected: False), Money {workPlayer.Money} (Expected: 1000)");

        // Test 3: Adult can work
        // Age is derived from Day / 365. To get age 18, we need 18 * 365 = 6570 days.
        int adultDays = 18 * 365;
        int realSecondsForAdultAge = adultDays * 24 * 60 / GameClock.MinutesPerRealSecond;
        workClock.AdvanceSeconds(realSecondsForAdultAge);

        Console.WriteLine($"Adult setup: Age {workPlayer.Age} (Expected: 18), LifeStage {workPlayer.LifeStage} (Expected: Adult)");
        
        // Explicitly verify StartWorking side effects
        int beforeWorkDay = workClock.Day;
        int beforeWorkHour = workClock.Hour;
        int beforeWorkMinute = workClock.Minute;
        int beforeWorkMoney = workPlayer.Money;
        int beforeWorkEnergy = workPlayer.Energy;
        int beforeWorkHunger = workPlayer.Hunger;
        int beforeWorkThirst = workPlayer.Thirst;
        
        workPlayer.StartWorking();
        
        bool startWorkClockUnchanged = (beforeWorkDay == workClock.Day) && (beforeWorkHour == workClock.Hour) && (beforeWorkMinute == workClock.Minute);
        bool startWorkStatsUnchanged = (beforeWorkMoney == workPlayer.Money) && (beforeWorkEnergy == workPlayer.Energy) && (beforeWorkHunger == workPlayer.Hunger) && (beforeWorkThirst == workPlayer.Thirst);

        Console.WriteLine($"StartWorking IsWorking = {workPlayer.IsWorking} (Expected: True)");
        Console.WriteLine($"StartWorking Clock Unchanged = {startWorkClockUnchanged} (Expected: True)");
        Console.WriteLine($"StartWorking Stats Unchanged = {startWorkStatsUnchanged} (Expected: True)");

        // Test 4: One working hour
        // Start from age 18.
        workPlayer.AdvanceSimulation(60);
        Console.WriteLine($"4. One working hour: Money {workPlayer.Money} (Expected: 1010), Energy {workPlayer.Energy} (Expected: 99), Hunger {workPlayer.Hunger} (Expected: 99), Thirst {workPlayer.Thirst} (Expected: 98), IsWorking {workPlayer.IsWorking} (Expected: True)");

        // Test 5 & 6: Multiple small updates (30 min + 30 min = 60 min, then 15+15+15+15)
        workPlayer.StopWorking();
        workPlayer.StartWorking();
        workPlayer.AdvanceSimulation(30);
        Console.WriteLine($"5a. Partial 30m work: Money {workPlayer.Money} (Expected: 1010)");
        workPlayer.AdvanceSimulation(30);
        Console.WriteLine($"5b. Another 30m work: Money {workPlayer.Money} (Expected: 1020)");

        // 15+15+15+15 = 60
        workPlayer.AdvanceSimulation(15);
        workPlayer.AdvanceSimulation(15);
        workPlayer.AdvanceSimulation(15);
        workPlayer.AdvanceSimulation(15);
        Console.WriteLine($"6. Four 15m updates: Money {workPlayer.Money} (Expected: 1030)");

        // Test 7: Two working hours
        workPlayer.AdvanceSimulation(120);
        Console.WriteLine($"7. Two working hours: Money {workPlayer.Money} (Expected: 1050)");

        // Test 8: Stop Work side effects
        int beforeDayWork = workClock.Day;
        int beforeHourWork = workClock.Hour;
        int beforeMinuteWork = workClock.Minute;
        int beforeMoneyWork = workPlayer.Money;
        int beforeEnergyWork = workPlayer.Energy;
        int beforeHungerWork = workPlayer.Hunger;
        int beforeThirstWork = workPlayer.Thirst;
        workPlayer.StopWorking();
        bool clockUnchangedWork = (beforeDayWork == workClock.Day) && (beforeHourWork == workClock.Hour) && (beforeMinuteWork == workClock.Minute);
        bool statsUnchangedWork = (beforeMoneyWork == workPlayer.Money) && (beforeEnergyWork == workPlayer.Energy) && (beforeHungerWork == workPlayer.Hunger) && (beforeThirstWork == workPlayer.Thirst);
        Console.WriteLine($"8. Stop Work: IsWorking {workPlayer.IsWorking} (Expected: False), Clock Unchanged: {clockUnchangedWork} (Expected: True), Stats Unchanged: {statsUnchangedWork} (Expected: True)");

        // Test 9: Partial work survives stopping
        workPlayer.StartWorking();
        workPlayer.AdvanceSimulation(30);
        workPlayer.StopWorking();
        Console.WriteLine($"9a. Worked 30m (accumulated 30m): Money {workPlayer.Money} (Expected: 1050)");
        workPlayer.StartWorking();
        workPlayer.AdvanceSimulation(30);
        Console.WriteLine($"9b. Worked another 30m (total 60m): Money {workPlayer.Money} (Expected: 1060)");

        // Test 10: Cannot work while sleeping
        workPlayer.StartSleeping();
        workPlayer.StartWorking();
        Console.WriteLine($"10. Cannot work while sleeping: IsSleeping {workPlayer.IsSleeping} (Expected: True), IsWorking {workPlayer.IsWorking} (Expected: False)");

        // Test 11: Cannot sleep while working
        workPlayer.StopSleeping();
        workPlayer.StartWorking();
        workPlayer.StartSleeping();
        Console.WriteLine($"11. Cannot sleep while working: IsWorking {workPlayer.IsWorking} (Expected: True), IsSleeping {workPlayer.IsSleeping} (Expected: False)");

        // Test 12: God Mode
        Console.WriteLine("\n--- LIFESTATE God Mode Tests ---");
        
        // 1. Disabled God Mode blocks mutation
        var disClock = new GameClock();
        var disPlayer = new PlayerState(disClock);
        var disGm = new GodMode(disClock, disPlayer);
        disGm.AdvanceDays(1);
        Console.WriteLine($"1. Disabled GM - AdvanceDays(1): Day {disClock.Day} (Expected: 0)");

        // 2. +1 Day
        var dClock = new GameClock();
        var dPlayer = new PlayerState(dClock);
        var dGm = new GodMode(dClock, dPlayer);
        dGm.SetEnabled(true);
        dGm.AdvanceDays(1);
        Console.WriteLine($"2. +1 Day: Day {dClock.Day} (Expected: 1)");

        // 3. +1 Year
        var yClock = new GameClock();
        var yPlayer = new PlayerState(yClock);
        var yGm = new GodMode(yClock, yPlayer);
        yGm.SetEnabled(true);
        yGm.AdvanceDays(365);
        Console.WriteLine($"3. +1 Year (Age): Age {yPlayer.Age} (Expected: 1)");

        // 4. +10 Years
        var tenYClock = new GameClock();
        var tenYPlayer = new PlayerState(tenYClock);
        var tenYGm = new GodMode(tenYClock, tenYPlayer);
        tenYGm.SetEnabled(true);
        tenYGm.AdvanceDays(3650);
        Console.WriteLine($"4. +10 Years (Age/LifeStage): Age {tenYPlayer.Age} (Expected: 10), LifeStage {tenYPlayer.LifeStage} (Expected: Child)");

        // 5. Disabled blocks Money
        var mClock = new GameClock();
        var mPlayer = new PlayerState(mClock);
        var mGm = new GodMode(mClock, mPlayer);
        mGm.AddMoney(100);
        Console.WriteLine($"5. Disabled GM - AddMoney: Money {mPlayer.Money} (Expected: 1000)");

        // 6. +100 Money
        mGm.SetEnabled(true);
        mGm.AddMoney(100);
        Console.WriteLine($"6. Enabled GM - AddMoney: Money {mPlayer.Money} (Expected: 1100)");

        // 7. Disabled blocks Restore Needs
        var nClock = new GameClock();
        var nPlayer = new PlayerState(nClock);
        var nGm = new GodMode(nClock, nPlayer);
        nPlayer.UpdateEnergy(60);
        nPlayer.UpdateHunger(60);
        nPlayer.UpdateThirst(60);
        int eBefore = nPlayer.Energy;
        nGm.RestoreNeeds();
        Console.WriteLine($"7. Disabled GM - RestoreNeeds: Energy {nPlayer.Energy} (Expected: {eBefore})");

        // 8. Enabled Restore Needs
        nGm.SetEnabled(true);
        nGm.RestoreNeeds();
        Console.WriteLine($"8. Enabled GM - RestoreNeeds: Energy {nPlayer.Energy}, Hunger {nPlayer.Hunger}, Thirst {nPlayer.Thirst} (Expected: 100, 100, 100)");

        // 9. Re-disabled GM
        var rClock = new GameClock();
        var rPlayer = new PlayerState(rClock);
        var rGm = new GodMode(rClock, rPlayer);
        rGm.SetEnabled(true);
        rGm.AdvanceDays(1);
        rGm.SetEnabled(false);
        rGm.AdvanceDays(1);
        Console.WriteLine($"9. Re-disabled GM - Day {rClock.Day} (Expected: 1)");


        // Study Tests
        Console.WriteLine("\n--- LIFESTATE Study Tests ---");

        // TEST 1 — FRESH PLAYER
        var s1Clock = new GameClock();
        var s1Player = new PlayerState(s1Clock);
        Console.WriteLine($"1. Fresh StudyXP: {s1Player.StudyXP} (Expected: 0)");
        Console.WriteLine($"1. Fresh IsStudying: {s1Player.IsStudying} (Expected: False)");

        // TEST 2 — NEWBORN CANNOT STUDY
        var s2Clock = new GameClock();
        var s2Player = new PlayerState(s2Clock);
        s2Player.StartStudying();
        Console.WriteLine($"2. Newborn IsStudying: {s2Player.IsStudying} (Expected: False), Energy: {s2Player.Energy} (Expected: 100), Money: {s2Player.Money} (Expected: 1000)");

        // TEST 3 — AGE 5 CANNOT STUDY
        var s3Clock = new GameClock();
        var s3Player = new PlayerState(s3Clock);
        var s3Gm = new GodMode(s3Clock, s3Player);
        s3Gm.SetEnabled(true);
        s3Gm.AdvanceDays(5 * 365);
        s3Player.StartStudying();
        Console.WriteLine($"3. Age 5 IsStudying: {s3Player.IsStudying} (Expected: False)");

        // TEST 4 — EXACT AGE 6 CAN STUDY
        var s4Clock = new GameClock();
        var s4Player = new PlayerState(s4Clock);
        var s4Gm = new GodMode(s4Clock, s4Player);
        s4Gm.SetEnabled(true);
        s4Gm.AdvanceDays(6 * 365);
        s4Player.StartStudying();
        Console.WriteLine($"4. Age 6 IsStudying: {s4Player.IsStudying} (Expected: True)");
        Console.WriteLine($"4. Side effects: Day {s4Clock.Day} (Expected: 2190), Energy {s4Player.Energy} (Expected: 100), Money {s4Player.Money} (Expected: 1000), StudyXP {s4Player.StudyXP} (Expected: 0)");

        // TEST 5 — 60 MINUTES STUDY
        var s5Clock = new GameClock();
        var s5Player = new PlayerState(s5Clock);
        var s5Gm = new GodMode(s5Clock, s5Player);
        s5Gm.SetEnabled(true);
        s5Gm.AdvanceDays(6 * 365);
        s5Player.StartStudying();
        s5Player.AdvanceSimulation(60);
        Console.WriteLine($"5. 60m StudyXP: {s5Player.StudyXP} (Expected: 10)");
        Console.WriteLine($"5. 60m Needs: Energy {s5Player.Energy} (Expected: 99), Hunger {s5Player.Hunger} (Expected: 99), Thirst {s5Player.Thirst} (Expected: 98)");

        // TEST 6 — PARTIAL STUDY ACCUMULATION
        var s6Clock = new GameClock();
        var s6Player = new PlayerState(s6Clock);
        var s6Gm = new GodMode(s6Clock, s6Player);
        s6Gm.SetEnabled(true);
        s6Gm.AdvanceDays(6 * 365);
        s6Player.StartStudying();
        s6Player.AdvanceSimulation(30);
        Console.WriteLine($"6a. 30m StudyXP: {s6Player.StudyXP} (Expected: 0)");
        s6Player.AdvanceSimulation(30);
        Console.WriteLine($"6b. +30m StudyXP: {s6Player.StudyXP} (Expected: 10)");

        // TEST 7 — MULTIPLE SMALL UPDATES
        var s7Clock = new GameClock();
        var s7Player = new PlayerState(s7Clock);
        var s7Gm = new GodMode(s7Clock, s7Player);
        s7Gm.SetEnabled(true);
        s7Gm.AdvanceDays(6 * 365);
        s7Player.StartStudying();
        s7Player.AdvanceSimulation(15);
        s7Player.AdvanceSimulation(15);
        s7Player.AdvanceSimulation(15);
        Console.WriteLine($"7a. 45m StudyXP: {s7Player.StudyXP} (Expected: 0)");
        s7Player.AdvanceSimulation(15);
        Console.WriteLine($"7b. 60m StudyXP: {s7Player.StudyXP} (Expected: 10)");

        // TEST 8 — 120 MINUTES
        var s8Clock = new GameClock();
        var s8Player = new PlayerState(s8Clock);
        var s8Gm = new GodMode(s8Clock, s8Player);
        s8Gm.SetEnabled(true);
        s8Gm.AdvanceDays(6 * 365);
        s8Player.StartStudying();
        s8Player.AdvanceSimulation(120);
        Console.WriteLine($"8. 120m StudyXP: {s8Player.StudyXP} (Expected: 20)");

        // TEST 9 — STOP STUDY HAS NO SIDE EFFECTS
        var s9Clock = new GameClock();
        var s9Player = new PlayerState(s9Clock);
        var s9Gm = new GodMode(s9Clock, s9Player);
        s9Gm.SetEnabled(true);
        s9Gm.AdvanceDays(6 * 365);
        s9Player.StartStudying();
        s9Player.AdvanceSimulation(30);
        int s9E = s9Player.Energy;
        int s9H = s9Player.Hunger;
        int s9T = s9Player.Thirst;
        int s9M = s9Player.Money;
        int s9XP = s9Player.StudyXP;
        int s9D = s9Clock.Day;
        s9Player.StopStudying();
        Console.WriteLine($"9. StopStudy IsStudying: {s9Player.IsStudying} (Expected: False)");
        Console.WriteLine($"9. Side effects: Day {s9Clock.Day} == {s9D}, Energy {s9Player.Energy} == {s9E}, Money {s9Player.Money} == {s9M}, StudyXP {s9Player.StudyXP} == {s9XP}");

        // TEST 10 — PARTIAL TIME SURVIVES STOP / START
        var s10Clock = new GameClock();
        var s10Player = new PlayerState(s10Clock);
        var s10Gm = new GodMode(s10Clock, s10Player);
        s10Gm.SetEnabled(true);
        s10Gm.AdvanceDays(6 * 365);
        s10Player.StartStudying();
        s10Player.AdvanceSimulation(30);
        s10Player.StopStudying();
        s10Player.StartStudying();
        s10Player.AdvanceSimulation(30);
        Console.WriteLine($"10. Persistent partial: StudyXP {s10Player.StudyXP} (Expected: 10)");

        // TEST 11 — CANNOT STUDY WHILE SLEEPING
        var s11Clock = new GameClock();
        var s11Player = new PlayerState(s11Clock);
        var s11Gm = new GodMode(s11Clock, s11Player);
        s11Gm.SetEnabled(true);
        s11Gm.AdvanceDays(6 * 365);
        s11Player.StartSleeping();
        s11Player.StartStudying();
        Console.WriteLine($"11. Study while sleeping: IsSleeping {s11Player.IsSleeping} (Expected: True), IsStudying {s11Player.IsStudying} (Expected: False)");

        // TEST 12 — CANNOT SLEEP WHILE STUDYING
        var s12Clock = new GameClock();
        var s12Player = new PlayerState(s12Clock);
        var s12Gm = new GodMode(s12Clock, s12Player);
        s12Gm.SetEnabled(true);
        s12Gm.AdvanceDays(6 * 365);
        s12Player.StartStudying();
        s12Player.StartSleeping();
        Console.WriteLine($"12. Sleep while studying: IsStudying {s12Player.IsStudying} (Expected: True), IsSleeping {s12Player.IsSleeping} (Expected: False)");

        // TEST 13 — CANNOT STUDY WHILE WORKING
        var s13Clock = new GameClock();
        var s13Player = new PlayerState(s13Clock);
        var s13Gm = new GodMode(s13Clock, s13Player);
        s13Gm.SetEnabled(true);
        s13Gm.AdvanceDays(18 * 365);
        s13Player.StartWorking();
        s13Player.StartStudying();
        Console.WriteLine($"13. Study while working: IsWorking {s13Player.IsWorking} (Expected: True), IsStudying {s13Player.IsStudying} (Expected: False)");

        // TEST 14 — CANNOT WORK WHILE STUDYING
        var s14Clock = new GameClock();
        var s14Player = new PlayerState(s14Clock);
        var s14Gm = new GodMode(s14Clock, s14Player);
        s14Gm.SetEnabled(true);
        s14Gm.AdvanceDays(18 * 365);
        s14Player.StartStudying();
        s14Player.StartWorking();
        Console.WriteLine($"14. Work while studying: IsStudying {s14Player.IsStudying} (Expected: True), IsWorking {s14Player.IsWorking} (Expected: False)");

        // TEST 15 — ADULTS CAN STUDY
        var s15Clock = new GameClock();
        var s15Player = new PlayerState(s15Clock);
        var s15Gm = new GodMode(s15Clock, s15Player);
        s15Gm.SetEnabled(true);
        s15Gm.AdvanceDays(25 * 365);
        s15Player.StartStudying();
        Console.WriteLine($"15. Adult study: Age {s15Player.Age} (Expected: 25), IsStudying {s15Player.IsStudying} (Expected: True)");

        // --- PERSISTENCE TESTS ---
        Console.WriteLine("\n--- LIFESTATE Save/Load Tests ---");

        RunSaveLoadTests();
        RunHardenedOfflineTests();
        RunBulkNeedSemanticsTests();
        RunAttributeTests();
        RunNeedPersistTests();
    }

    private static void RunSaveLoadTests()
    {
        Console.WriteLine("\n--- LIFESTATE Save/Load Regression Tests ---");

        // Helper to run a test with an isolated save path
        void RunWithTempSave(Action<string> testAction)
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "LIFESTATE-tests", Guid.NewGuid().ToString());
            string tempSavePath = Path.Combine(tempDir, "save.json");
            try
            {
                Directory.CreateDirectory(tempDir);
                testAction(tempSavePath);
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }

        // Test 1: Basic Round Trip
        RunWithTempSave(path => {
            var clock = new GameClock();
            clock.AdvanceSeconds(60); // 4 mins
            var player = new PlayerState(clock);
            player.Drink(10); // Thirst 110 -> 100
            player.UpdateEnergy(30);
            
            SaveManager.Save(clock, player, path);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path);
            
            bool match = loaded && loadClock.Day == clock.Day && loadClock.Hour == clock.Hour && loadClock.Minute == clock.Minute &&
                         loadPlayer.Money == player.Money && loadPlayer.Energy == player.Energy &&
                         loadPlayer.Hunger == player.Hunger && loadPlayer.Thirst == player.Thirst &&
                         loadPlayer.StudyXP == player.StudyXP;
            Console.WriteLine($"1. Basic Round Trip: {match} (Expected: True)");
        });

        // Test 2: Age remains derived
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(25 * 365);
            SaveManager.Save(clock, player, path);
            
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            SaveManager.Load(loadClock, loadPlayer, path);
            
            bool match = loadPlayer.Age == 25 && loadPlayer.LifeStage == LifeStage.Adult;
            Console.WriteLine($"2. Age/LifeStage Derived: {match} (Expected: True)");
        });

        // Test 3: Sleep state survives
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.UpdateEnergy(50 * 60); // Drain
            player.StartSleeping();
            SaveManager.Save(clock, player, path);
            
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            SaveManager.Load(loadClock, loadPlayer, path);
            
            bool stateMatch = loadPlayer.IsSleeping && !loadPlayer.IsWorking && !loadPlayer.IsStudying;
            loadPlayer.AdvanceSimulation(60);
            bool recovery = loadPlayer.Energy > player.Energy;
            Console.WriteLine($"3. Sleep state survives/recovers: {stateMatch && recovery} (Expected: True)");
        });

        // Test 4: Work state survives (Age >= 18)
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(18 * 365);
            player.StartWorking();
            SaveManager.Save(clock, player, path);
            
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            SaveManager.Load(loadClock, loadPlayer, path);
            
            bool stateMatch = loadPlayer.IsWorking && !loadPlayer.IsSleeping && !loadPlayer.IsStudying;
            Console.WriteLine($"4. Work state survives: {stateMatch} (Expected: True)");
        });

        // Test 5: Work partial progress
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(18 * 365);
            player.StartWorking();
            player.AdvanceSimulation(30);
            int moneyBefore = player.Money;
            SaveManager.Save(clock, player, path);
            
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            SaveManager.Load(loadClock, loadPlayer, path);
            
            bool moneyMatch = loadPlayer.Money == moneyBefore;
            loadPlayer.AdvanceSimulation(30);
            bool moneyIncreased = loadPlayer.Money == moneyBefore + 10;
            Console.WriteLine($"5. Work partial progress: {moneyMatch && moneyIncreased} (Expected: True)");
        });

        // Test 6: Study state survives (Age >= 6)
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(6 * 365);
            player.StartStudying();
            SaveManager.Save(clock, player, path);
            
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            SaveManager.Load(loadClock, loadPlayer, path);
            
            bool stateMatch = loadPlayer.IsStudying && !loadPlayer.IsSleeping && !loadPlayer.IsWorking;
            Console.WriteLine($"6. Study state survives: {stateMatch} (Expected: True)");
        });

        // Test 7: Study partial progress
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(6 * 365);
            player.StartStudying();
            player.AdvanceSimulation(30);
            int xpBefore = player.StudyXP;
            SaveManager.Save(clock, player, path);
            
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            SaveManager.Load(loadClock, loadPlayer, path);
            
            bool xpMatch = loadPlayer.StudyXP == xpBefore;
            loadPlayer.AdvanceSimulation(30);
            bool xpIncreased = loadPlayer.StudyXP == xpBefore + 10;
            Console.WriteLine($"7. Study partial progress: {xpMatch && xpIncreased} (Expected: True)");
        });

        // Test 8: Save does not mutate state
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.UpdateEnergy(10);
            var money = player.Money;
            var energy = player.Energy;
            var hunger = player.Hunger;
            var thirst = player.Thirst;
            var studyXP = player.StudyXP;
            SaveManager.Save(clock, player, path);
            bool unchanged = player.Money == money && player.Energy == energy && player.Hunger == hunger && 
                             player.Thirst == thirst && player.StudyXP == studyXP;
            Console.WriteLine($"8. Save does not mutate state: {unchanged} (Expected: True)");
        });

        // Test 9: Load does not simulate offline time
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            SaveManager.Save(clock, player, path);
            
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            SaveManager.Load(loadClock, loadPlayer, path);
            
            bool unchanged = loadClock.Day == clock.Day && loadClock.Hour == clock.Hour && loadClock.Minute == clock.Minute &&
                             loadPlayer.Money == player.Money && loadPlayer.Energy == player.Energy;
            Console.WriteLine($"9. Load does not simulate offline: {unchanged} (Expected: True)");
        });

        // Test 10: Missing save file
        bool loaded = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), "nonexistent_file.json");
        Console.WriteLine($"10. Missing save file: {loaded == false} (Expected: True)");

        // Test 11: Invalid JSON
        RunWithTempSave(path => {
            File.WriteAllText(path, "{ invalid json }");
            bool loaded = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), path);
            Console.WriteLine($"11. Invalid JSON: {loaded == false} (Expected: True)");
        });

        // Test 12: Invalid activity combination (sleeping + working)
        RunWithTempSave(path => {
            File.WriteAllText(path, "{\"Version\":1, \"IsSleeping\":true, \"IsWorking\":true}");
            bool loaded = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), path);
            Console.WriteLine($"12. Invalid activity combination: {loaded == false} (Expected: True)");
        });

        // Test 13: Invalid need value (Energy 999)
        RunWithTempSave(path => {
            File.WriteAllText(path, "{\"Version\":1, \"Energy\":999}");
            bool loaded = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), path);
            Console.WriteLine($"13. Invalid need value: {loaded == false} (Expected: True)");
        });

        // Test 14: Wrong version
        RunWithTempSave(path => {
            File.WriteAllText(path, "{\"Version\":999}");
            bool loaded = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), path);
            Console.WriteLine($"14. Wrong version: {loaded == false} (Expected: True)");
        });

        // Test 15: God Mode non-persistence
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            SaveManager.Save(clock, player, path);
            
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            var loadGm = new GodMode(loadClock, loadPlayer);
            SaveManager.Load(loadClock, loadPlayer, path);
            
            Console.WriteLine($"15. God Mode non-persistence: {loadGm.IsEnabled == false} (Expected: True)");
        });

        // Clock Validation Tests
        RunWithTempSave(path => {
            // Day -1
            File.WriteAllText(path, "{\"Version\":1, \"Day\":-1}");
            bool loadedDay = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), path);
            // Hour 24
            File.WriteAllText(path, "{\"Version\":1, \"Day\":0, \"Hour\":24}");
            bool loadedHour = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), path);
            // Minute 60
            File.WriteAllText(path, "{\"Version\":1, \"Day\":0, \"Hour\":0, \"Minute\":60}");
            bool loadedMinute = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), path);
            
            Console.WriteLine($"Clock Validation: {loadedDay == false && loadedHour == false && loadedMinute == false} (Expected: True)");
        });

        // Test 16: Offline Progression
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            // 15 seconds real time = 60 minutes in-game
            DateTimeOffset past = DateTimeOffset.UtcNow.AddSeconds(-15);
            SaveManager.Save(clock, player, path, past);
            
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            // Load now with current time.
            SaveManager.Load(loadClock, loadPlayer, path, DateTimeOffset.UtcNow);
            
            // Expected: 60 minutes passed. Energy/Needs should have decreased.
            bool advanced = loadClock.Hour == 1 || (loadClock.Hour == 0 && loadClock.Minute > 0);
            bool statsChanged = loadPlayer.Energy < 100;
            Console.WriteLine($"16. Offline progression: {advanced && statsChanged} (Expected: True)");
        });



        // --- Offline Progression Regression Tests ---
        DateTimeOffset offlineT = new DateTimeOffset(2026, 9, 9, 12, 0, 0, TimeSpan.Zero);

        // Offline-T1: ZERO OFFLINE TIME
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(20 * 365); // Adult
            player.DebugAddMoney(500); // Money 1500
            player.StartWorking();
            player.AdvanceSimulation(30); 
            player.StopWorking();
            player.StartStudying();
            player.AdvanceSimulation(15);
            player.StopStudying();
            
            int savedDay = clock.Day;
            int savedHour = clock.Hour;
            int savedMinute = clock.Minute;
            int savedMoney = player.Money;
            int savedEnergy = player.Energy;
            int savedHunger = player.Hunger;
            int savedThirst = player.Thirst;
            int savedXP = player.StudyXP;
            bool savedSleep = player.IsSleeping;
            bool savedWork = player.IsWorking;
            bool savedStudy = player.IsStudying;
            int savedWorkAcc = player.GetWorkMinutesAccumulator();
            int savedStudyAcc = player.GetStudyMinutesAccumulator();

            SaveManager.Save(clock, player, path, offlineT);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, offlineT);

            bool pass = loaded &&
                        loadClock.Day == savedDay && loadClock.Hour == savedHour && loadClock.Minute == savedMinute &&
                        loadPlayer.Money == savedMoney && loadPlayer.Energy == savedEnergy &&
                        loadPlayer.Hunger == savedHunger && loadPlayer.Thirst == savedThirst &&
                        loadPlayer.StudyXP == savedXP && loadPlayer.IsSleeping == savedSleep &&
                        loadPlayer.IsWorking == savedWork && loadPlayer.IsStudying == savedStudy &&
                        loadPlayer.GetWorkMinutesAccumulator() == savedWorkAcc &&
                        loadPlayer.GetStudyMinutesAccumulator() == savedStudyAcc;
            
            Console.WriteLine($"Offline-T1: {pass} (Expected: True)");
        });

        // Offline-T2: 15 REAL SECONDS
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            SaveManager.Save(clock, player, path, offlineT);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, offlineT.AddSeconds(15));
            
            bool pass = loaded &&
                        loadClock.Day == 0 && loadClock.Hour == 1 && loadClock.Minute == 0 &&
                        loadPlayer.Energy == 99 && loadPlayer.Hunger == 99 && loadPlayer.Thirst == 98 &&
                        loadPlayer.Money == 1000 && loadPlayer.StudyXP == 0 &&
                        !loadPlayer.IsSleeping && !loadPlayer.IsWorking && !loadPlayer.IsStudying;
            Console.WriteLine($"Offline-T2: {pass} (Expected: True)");
        });

        // Offline-T3: 6 REAL MINUTES
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            SaveManager.Save(clock, player, path, offlineT);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, offlineT.AddMinutes(6));
            bool pass = loaded && loadClock.Day == 1 && loadClock.Hour == 0 && loadClock.Minute == 0;
            Console.WriteLine($"Offline-T3: {pass} (Expected: True)");
        });

        // Offline-T4: ONE REAL HOUR
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            SaveManager.Save(clock, player, path, offlineT);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, offlineT.AddHours(1));
            bool pass = loaded && loadClock.Day == 10 && loadClock.Hour == 0 && loadClock.Minute == 0;
            Console.WriteLine($"Offline-T4: {pass} (Expected: True)");
        });

        // Offline-T5: FUTURE TIMESTAMP
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.DebugAddMoney(100);
            int sMoney = player.Money;
            int sEnergy = player.Energy;
            SaveManager.Save(clock, player, path, offlineT.AddHours(1));
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, offlineT);
            bool pass = loaded && loadClock.Day == 0 && loadClock.Hour == 0 &&
                        loadPlayer.Money == sMoney && loadPlayer.Energy == sEnergy;
            Console.WriteLine($"Offline-T5: {pass} (Expected: True)");
        });

        // Offline-T6: WORK
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(20 * 365);
            player.StartWorking();
            int moneyBefore = player.Money;
            int energyBefore = player.Energy;
            int hungerBefore = player.Hunger;
            int thirstBefore = player.Thirst;
            SaveManager.Save(clock, player, path, offlineT);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, offlineT.AddSeconds(15));
            bool pass = loaded && loadPlayer.IsWorking &&
                        loadPlayer.Money == moneyBefore + 10 &&
                        loadPlayer.Energy == energyBefore - 1 &&
                        loadPlayer.Hunger == hungerBefore - 1 &&
                        loadPlayer.Thirst == thirstBefore - 2 &&
                        loadPlayer.StudyXP == 0;
            Console.WriteLine($"Offline-T6: {pass} (Expected: True)");
        });

        // Offline-T7: STUDY
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(10 * 365);
            player.StartStudying();
            int xpBefore = player.StudyXP;
            int energyBefore = player.Energy;
            int hungerBefore = player.Hunger;
            int thirstBefore = player.Thirst;
            SaveManager.Save(clock, player, path, offlineT);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, offlineT.AddSeconds(15));
            bool pass = loaded && loadPlayer.IsStudying &&
                        loadPlayer.StudyXP == xpBefore + 10 &&
                        loadPlayer.Energy == energyBefore - 1 &&
                        loadPlayer.Hunger == hungerBefore - 1 &&
                        loadPlayer.Thirst == thirstBefore - 2 &&
                        loadPlayer.Money == 1000;
            Console.WriteLine($"Offline-T7: {pass} (Expected: True)");
        });

        // Offline-T8: SLEEP
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.UpdateEnergy(20 * 60); // 100 -> 80
            player.StartSleeping();
            int energyBefore = player.Energy;
            SaveManager.Save(clock, player, path, offlineT);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, offlineT.AddSeconds(15));
            bool pass = loaded && loadPlayer.IsSleeping &&
                        loadPlayer.Energy == 85 &&
                        loadPlayer.Hunger == 99 &&
                        loadPlayer.Thirst == 98 &&
                        loadPlayer.Money == 1000 &&
                        loadPlayer.StudyXP == 0;
            Console.WriteLine($"Offline-T8: {pass} (Expected: True)");
        });

        // Offline-T9: VERSION 1 REJECTION
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.DebugAddMoney(50);
            int m = player.Money;
            int e = player.Energy;
            File.WriteAllText(path, "{\"Version\":1, \"Money\":5000, \"Energy\":10}");
            bool loaded = SaveManager.Load(clock, player, path, offlineT);
            bool pass = !loaded && player.Money == m && player.Energy == e;
            Console.WriteLine($"Offline-T9: {pass} (Expected: True)");
        });

        // Offline-T10A/B: SAVEDATUTC VALIDATION
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            int m = player.Money;

            // T10A: Missing SavedAtUtc
            File.WriteAllText(path, "{\"Version\":2, \"Money\":5000}");
            bool loadedA = SaveManager.Load(clock, player, path, offlineT);
            bool passA = !loadedA && player.Money == m;
            Console.WriteLine($"Offline-T10A: {passA} (Expected: True)");

            // T10B: Default SavedAtUtc
            File.WriteAllText(path, "{\"Version\":2, \"Money\":5000, \"SavedAtUtc\":\"0001-01-01T00:00:00+00:00\"}");
            bool loadedB = SaveManager.Load(clock, player, path, offlineT);
            bool passB = !loadedB && player.Money == m;
            Console.WriteLine($"Offline-T10B: {passB} (Expected: True)");
        });


    }

    private static void RunHardenedOfflineTests()
    {
        Console.WriteLine("\n--- LIFESTATE Hardened Offline Regression Tests ---");

        void RunWithTempSave(Action<string> testAction)
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "LIFESTATE-tests-H", Guid.NewGuid().ToString());
            string tempSavePath = Path.Combine(tempDir, "save.json");
            try
            {
                Directory.CreateDirectory(tempDir);
                testAction(tempSavePath);
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }

        DateTimeOffset baseTime = new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);

        // Offline-H1 — large idle duration completes correctly
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            SaveManager.Save(clock, player, path, baseTime);

            // 1000 days = 1000 * 24 * 60 = 1,440,000 game minutes
            // Real seconds = 1,440,000 / 4 = 360,000 seconds
            DateTimeOffset loadTime = baseTime.AddSeconds(360000);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            bool pass = loaded && loadClock.Day == 1000 && loadClock.Hour == 0 && loadClock.Minute == 0 &&
                        loadPlayer.Energy == 0 && loadPlayer.Hunger == 0 && loadPlayer.Thirst == 0 &&
                        loadPlayer.Money == 1000 && loadPlayer.StudyXP == 0;
            if (!pass) Console.WriteLine($"DEBUG H1: loaded={loaded}, Day={loadClock.Day}, Energy={loadPlayer.Energy}");
            Console.WriteLine($"Offline-H1: {pass} (Expected: True)");
        });

        // Offline-H2 — large Work progression exact reward
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(20 * 365); // Adult
            player.StartWorking();
            SaveManager.Save(clock, player, path, baseTime);

            // 100 hours = 6000 game minutes = 1500 real seconds
            DateTimeOffset loadTime = baseTime.AddSeconds(1500);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            // 100 hours = 4 days and 4 hours
            bool pass = loaded && loadClock.Day == (20 * 365) + 4 && loadClock.Hour == 4 && loadClock.Minute == 0 &&
                        loadPlayer.Money == 2000 && loadPlayer.Energy == 0 &&
                        loadPlayer.Hunger == 0 && loadPlayer.Thirst == 0 && loadPlayer.IsWorking;
            if (!pass) Console.WriteLine($"DEBUG H2: loaded={loaded}, Day={loadClock.Day}, Hour={loadClock.Hour}, Money={loadPlayer.Money}");
            Console.WriteLine($"Offline-H2: {pass} (Expected: True)");
        });

        // Offline-H3 — large Study progression exact reward
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(10 * 365); // Child
            player.StartStudying();
            SaveManager.Save(clock, player, path, baseTime);

            // 50 hours = 3000 game minutes = 750 real seconds
            DateTimeOffset loadTime = baseTime.AddSeconds(750);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            // StudyXP: 0 + (50 * 10) = 500
            bool pass = loaded && loadClock.Hour == 2 && loadClock.Minute == 0 &&
                        loadPlayer.StudyXP == 500 && loadPlayer.IsStudying;
            Console.WriteLine($"Offline-H3: {pass} (Expected: True)");
        });

        // Offline-H4 — Money overflow rejection is transactional
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(20 * 365);
            player.DebugAddMoney(int.MaxValue - 50); 
            player.StartWorking();
            SaveManager.Save(clock, player, path, baseTime);

            // 10 hours = 600 game minutes = 150 real seconds
            // Reward = 10 * 10 = 100. int.MaxValue - 50 + 100 > int.MaxValue
            DateTimeOffset loadTime = baseTime.AddSeconds(150);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            // Setup target state to something recognizable
            loadPlayer.DebugAddMoney(-900); // 1000 -> 100
            int targetMoney = loadPlayer.Money;

            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            bool pass = !loaded && loadPlayer.Money == targetMoney && loadClock.Day == 0;
            Console.WriteLine($"Offline-H4: {pass} (Expected: True)");
        });

        // Offline-H5 — StudyXP overflow rejection is transactional
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(10 * 365);
            // Manually set StudyXP near limit (need reflection or internal access)
            // But we don't have a DebugSetStudyXP. Let's use SaveManager.Load with a custom JSON
            File.WriteAllText(path, "{\"Version\":2,\"Day\":3650,\"StudyXP\":2147483600,\"IsStudying\":true,\"SavedAtUtc\":\"2026-01-01T12:00:00+00:00\"}");

            // 10 hours = 100 XP. 2147483600 + 100 overflows.
            DateTimeOffset loadTime = baseTime.AddSeconds(150);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);

            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            bool pass = !loaded && loadPlayer.StudyXP == 0 && loadClock.Day == 0;
            Console.WriteLine($"Offline-H5: {pass} (Expected: True)");
        });

        // Offline-H6 — clock overflow rejection remains transactional
        RunWithTempSave(path => {
            // Save with Day = int.MaxValue - 100
            File.WriteAllText(path, "{\"Version\":2,\"Day\":2147483547,\"SavedAtUtc\":\"2026-01-01T12:00:00+00:00\"}");

            // Add 1000 days
            DateTimeOffset loadTime = baseTime.AddDays(1);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            int targetDay = loadClock.Day;

            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            bool pass = !loaded && loadClock.Day == targetDay;
            Console.WriteLine($"Offline-H6: {pass} (Expected: True)");
        });

        // Offline-H7 — future timestamp semantics unchanged
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.DebugAddMoney(500);
            SaveManager.Save(clock, player, path, baseTime.AddHours(1));

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, baseTime);

            bool pass = loaded && loadPlayer.Money == 1500 && loadClock.Day == 0 && loadClock.Hour == 0;
            Console.WriteLine($"Offline-H7: {pass} (Expected: True)");
        });

        // Offline-H8 — fractional real seconds remain truncated
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            SaveManager.Save(clock, player, path, baseTime);

            // 15.9 seconds -> should be treated as 15 seconds (60 mins)
            DateTimeOffset loadTime = baseTime.AddSeconds(15.9);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            bool pass = loaded && loadClock.Hour == 1 && loadClock.Minute == 0;
            Console.WriteLine($"Offline-H8: {pass} (Expected: True)");
        });
    }

    private static void RunBulkNeedSemanticsTests()
    {
        Console.WriteLine("\n--- LIFESTATE BulkNeed-Semantics Regression Tests ---");

        // BulkNeed-R1: Awake 10,001 minute exactness
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            // Reference
            var refPlayer = new PlayerState(new GameClock());
            // Bulk
            player.BulkAdvanceSimulation(10001, out _, out _);
            refPlayer.AdvanceSimulation(10001);

            bool pass = player.Energy == refPlayer.Energy && player.Hunger == refPlayer.Hunger && player.Thirst == refPlayer.Thirst;
            
            // Follow up 19 mins
            player.BulkAdvanceSimulation(19, out _, out _);
            refPlayer.AdvanceSimulation(19);
            pass &= player.Energy == refPlayer.Energy && player.Hunger == refPlayer.Hunger && player.Thirst == refPlayer.Thirst;

            // Follow up 1 min
            player.BulkAdvanceSimulation(1, out _, out _);
            refPlayer.AdvanceSimulation(1);
            pass &= player.Energy == refPlayer.Energy && player.Hunger == refPlayer.Hunger && player.Thirst == refPlayer.Thirst;
            
            Console.WriteLine($"BulkNeed-R1: {pass} (Expected: True)");
        }

        // BulkNeed-R2: Sleeping 10,001 minute exactness
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.StartSleeping();
            var refPlayer = new PlayerState(new GameClock());
            refPlayer.StartSleeping();
            
            player.BulkAdvanceSimulation(10001, out _, out _);
            refPlayer.AdvanceSimulation(10001);
            
            bool pass = player.Energy == refPlayer.Energy && player.Hunger == refPlayer.Hunger && player.Thirst == refPlayer.Thirst && player.IsSleeping == refPlayer.IsSleeping;
            
            // Follow up 19 mins
            player.BulkAdvanceSimulation(19, out _, out _);
            refPlayer.AdvanceSimulation(19);
            pass &= player.Energy == refPlayer.Energy && player.Hunger == refPlayer.Hunger && player.Thirst == refPlayer.Thirst;

            // Follow up 1 min
            player.BulkAdvanceSimulation(1, out _, out _);
            refPlayer.AdvanceSimulation(1);
            pass &= player.Energy == refPlayer.Energy && player.Hunger == refPlayer.Hunger && player.Thirst == refPlayer.Thirst;
            
            Console.WriteLine($"BulkNeed-R2: {pass} (Expected: True)");
        }

        // BulkNeed-R3: Non-zero existing partial remainder
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            
            player.AdvanceSimulation(17);
            
            var refPlayer = new PlayerState(new GameClock());
            refPlayer.AdvanceSimulation(17);
            
            player.BulkAdvanceSimulation(10001, out _, out _);
            refPlayer.AdvanceSimulation(10001);
            
            bool pass = player.Energy == refPlayer.Energy && player.Hunger == refPlayer.Hunger && player.Thirst == refPlayer.Thirst;
            
            // Crossing hourly threshold
            player.AdvanceSimulation(60);
            refPlayer.AdvanceSimulation(60);
            pass &= player.Energy == refPlayer.Energy && player.Hunger == refPlayer.Hunger && player.Thirst == refPlayer.Thirst;
            
            Console.WriteLine($"BulkNeed-R3: {pass} (Expected: True)");
        }
    }

    private static void RunAttributeTests()
    {
        Console.WriteLine("\n--- LIFESTATE Core Attribute Regression Tests ---");

        // --- Attribute-A1: Defaults ---
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            bool pass = Math.Abs(player.Attributes.Intelligence - 10.0) < 0.000001 &&
                        Math.Abs(player.Attributes.Fitness - 10.0) < 0.000001 &&
                        Math.Abs(player.Attributes.Social - 10.0) < 0.000001 &&
                        Math.Abs(player.Attributes.Discipline - 10.0) < 0.000001 &&
                        Math.Abs(player.Attributes.Creativity - 10.0) < 0.000001;
            Console.WriteLine($"Attribute-A1: {pass} (Expected: True)");
        }

        // --- Attribute-A2: Study 59 Minutes ---
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(10 * 365);
            player.StartStudying();
            player.AdvanceSimulation(59);
            bool pass = player.StudyXP == 0 && Math.Abs(player.Attributes.Intelligence - 10.0) < 0.000001;
            Console.WriteLine($"Attribute-A2: {pass} (Expected: True)");
        }

        // --- Attribute-A3: Study Completes One Hour ---
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(10 * 365);
            player.StartStudying();
            player.AdvanceSimulation(60);
            bool pass = player.StudyXP == 10 && Math.Abs(player.Attributes.Intelligence - 10.05) < 0.000001;
            Console.WriteLine($"Attribute-A3: {pass} (Expected: True)");
        }

        // --- Attribute-A4: Study Partial Stop/Resume ---
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(10 * 365);
            player.StartStudying();
            player.AdvanceSimulation(35);
            player.StopStudying();
            player.AdvanceSimulation(30);
            player.StartStudying();
            player.AdvanceSimulation(25);
            bool pass = player.StudyXP == 10 && Math.Abs(player.Attributes.Intelligence - 10.05) < 0.000001;
            Console.WriteLine($"Attribute-A4: {pass} (Expected: True)");
        }

        // --- Attribute-A5: Intelligence Cap ---
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(10 * 365);
            player.Attributes.AddIntelligence(89.98);
            player.StartStudying();
            player.AdvanceSimulation(60);
            bool capAfterFirst = Math.Abs(player.Attributes.Intelligence - 100.0) < 0.000001 && player.StudyXP == 10;
            player.AdvanceSimulation(120);
            bool capSustained = Math.Abs(player.Attributes.Intelligence - 100.0) < 0.000001 && player.StudyXP == 30;
            bool pass = capAfterFirst && capSustained;
            Console.WriteLine($"Attribute-A5: {pass} (Expected: True)");
        }

        // --- Attribute-A6: Controlled Mutation Clamp ---
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.Attributes.AddIntelligence(200.0);
            bool clampPos = Math.Abs(player.Attributes.Intelligence - 100.0) < 0.000001;
            player.Attributes.AddIntelligence(-300.0);
            bool clampNeg = Math.Abs(player.Attributes.Intelligence - 0.0) < 0.000001;
            Console.WriteLine($"Attribute-A6: {clampPos && clampNeg} (Expected: True)");
        }

        // --- Attribute-A7: Invalid Floating-Point Mutation (strengthened: no-op) ---
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);

            // Set non-default known values for all five attributes
            player.Attributes.AddIntelligence(42.0);   // 10 + 42 = 52
            player.Attributes.AddFitness(67.0);        // 10 + 67 = 77
            player.Attributes.AddSocial(15.5);         // 10 + 15.5 = 25.5
            player.Attributes.AddDiscipline(88.0);     // 10 + 88 = 98
            player.Attributes.AddCreativity(31.25);    // 10 + 31.25 = 41.25

            double intelBefore = player.Attributes.Intelligence;
            double fitnessBefore = player.Attributes.Fitness;
            double socialBefore = player.Attributes.Social;
            double disciplineBefore = player.Attributes.Discipline;
            double creativityBefore = player.Attributes.Creativity;

            // Attempt NaN mutations — all must be no-op
            player.Attributes.AddIntelligence(double.NaN);
            player.Attributes.AddFitness(double.NaN);
            player.Attributes.AddSocial(double.NaN);
            player.Attributes.AddDiscipline(double.NaN);
            player.Attributes.AddCreativity(double.NaN);

            bool nanNoop = Math.Abs(player.Attributes.Intelligence - intelBefore) < 0.000001 &&
                           Math.Abs(player.Attributes.Fitness - fitnessBefore) < 0.000001 &&
                           Math.Abs(player.Attributes.Social - socialBefore) < 0.000001 &&
                           Math.Abs(player.Attributes.Discipline - disciplineBefore) < 0.000001 &&
                           Math.Abs(player.Attributes.Creativity - creativityBefore) < 0.000001;

            // Attempt +Infinity mutations — all must be no-op
            player.Attributes.AddIntelligence(double.PositiveInfinity);
            player.Attributes.AddFitness(double.PositiveInfinity);
            player.Attributes.AddSocial(double.PositiveInfinity);
            player.Attributes.AddDiscipline(double.PositiveInfinity);
            player.Attributes.AddCreativity(double.PositiveInfinity);

            bool posInfNoop = Math.Abs(player.Attributes.Intelligence - intelBefore) < 0.000001 &&
                              Math.Abs(player.Attributes.Fitness - fitnessBefore) < 0.000001 &&
                              Math.Abs(player.Attributes.Social - socialBefore) < 0.000001 &&
                              Math.Abs(player.Attributes.Discipline - disciplineBefore) < 0.000001 &&
                              Math.Abs(player.Attributes.Creativity - creativityBefore) < 0.000001;

            // Attempt -Infinity mutations — all must be no-op
            player.Attributes.AddIntelligence(double.NegativeInfinity);
            player.Attributes.AddFitness(double.NegativeInfinity);
            player.Attributes.AddSocial(double.NegativeInfinity);
            player.Attributes.AddDiscipline(double.NegativeInfinity);
            player.Attributes.AddCreativity(double.NegativeInfinity);

            bool negInfNoop = Math.Abs(player.Attributes.Intelligence - intelBefore) < 0.000001 &&
                              Math.Abs(player.Attributes.Fitness - fitnessBefore) < 0.000001 &&
                              Math.Abs(player.Attributes.Social - socialBefore) < 0.000001 &&
                              Math.Abs(player.Attributes.Discipline - disciplineBefore) < 0.000001 &&
                              Math.Abs(player.Attributes.Creativity - creativityBefore) < 0.000001;

            bool pass = nanNoop && posInfNoop && negInfNoop;
            Console.WriteLine($"Attribute-A7: {pass} (Expected: True)");
        }

        // --- Attribute-A8: Save/Load Round Trip ---
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "LIFESTATE-tests-A", Guid.NewGuid().ToString());
            string tempPath = Path.Combine(tempDir, "save.json");
            try
            {
                Directory.CreateDirectory(tempDir);
                var clock = new GameClock();
                var player = new PlayerState(clock);
                player.Attributes.AddIntelligence(42.0);
                player.Attributes.AddFitness(67.0);
                player.Attributes.AddSocial(15.5);
                player.Attributes.AddDiscipline(88.0);
                player.Attributes.AddCreativity(31.25);
                SaveManager.Save(clock, player, tempPath);

                var loadClock = new GameClock();
                var loadPlayer = new PlayerState(loadClock);
                bool loaded = SaveManager.Load(loadClock, loadPlayer, tempPath);
                bool pass = loaded &&
                    Math.Abs(loadPlayer.Attributes.Intelligence - 52.0) < 0.000001 &&
                    Math.Abs(loadPlayer.Attributes.Fitness - 77.0) < 0.000001 &&
                    Math.Abs(loadPlayer.Attributes.Social - 25.5) < 0.000001 &&
                    Math.Abs(loadPlayer.Attributes.Discipline - 98.0) < 0.000001 &&
                    Math.Abs(loadPlayer.Attributes.Creativity - 41.25) < 0.000001 &&
                    loadPlayer.Money == player.Money;
                Console.WriteLine($"Attribute-A8: {pass} (Expected: True)");
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }

        // --- Attribute-A9: Explicit Zero Persistence ---
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "LIFESTATE-tests-A9", Guid.NewGuid().ToString());
            string tempPath = Path.Combine(tempDir, "save.json");
            try
            {
                Directory.CreateDirectory(tempDir);
                var clock = new GameClock();
                var player = new PlayerState(clock);
                player.Attributes.AddIntelligence(-10.0);
                SaveManager.Save(clock, player, tempPath);

                var loadClock = new GameClock();
                var loadPlayer = new PlayerState(loadClock);
                bool loaded = SaveManager.Load(loadClock, loadPlayer, tempPath);
                bool pass = loaded && Math.Abs(loadPlayer.Attributes.Intelligence - 0.0) < 0.000001;
                Console.WriteLine($"Attribute-A9: {pass} (Expected: True)");
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }

        // --- Attribute-A10: Old Version 2 Compatibility ---
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "LIFESTATE-tests-A10", Guid.NewGuid().ToString());
            string tempPath = Path.Combine(tempDir, "save.json");
            try
            {
                Directory.CreateDirectory(tempDir);
                DateTimeOffset baseTime = new DateTimeOffset(2026, 6, 15, 12, 0, 0, TimeSpan.Zero);
                File.WriteAllText(tempPath, "{\"Version\":2,\"Day\":1000,\"Hour\":5,\"Minute\":30,\"Money\":1500,\"Energy\":80,\"Hunger\":70,\"Thirst\":60,\"StudyXP\":50,\"IsSleeping\":false,\"IsWorking\":false,\"IsStudying\":false,\"WorkMinutesAccumulator\":0,\"StudyMinutesAccumulator\":0,\"SavedAtUtc\":\"2026-06-15T12:00:00+00:00\"}");

                var loadClock = new GameClock();
                var loadPlayer = new PlayerState(loadClock);
                bool loaded = SaveManager.Load(loadClock, loadPlayer, tempPath, baseTime);
                bool pass = loaded &&
                    Math.Abs(loadPlayer.Attributes.Intelligence - 10.0) < 0.000001 &&
                    Math.Abs(loadPlayer.Attributes.Fitness - 10.0) < 0.000001 &&
                    Math.Abs(loadPlayer.Attributes.Social - 10.0) < 0.000001 &&
                    Math.Abs(loadPlayer.Attributes.Discipline - 10.0) < 0.000001 &&
                    Math.Abs(loadPlayer.Attributes.Creativity - 10.0) < 0.000001 &&
                    loadClock.Day == 1000 && loadPlayer.Money == 1500;
                Console.WriteLine($"Attribute-A10: {pass} (Expected: True)");
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }

        // --- Attribute-A11: Invalid Saved Attribute Rejection ---
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "LIFESTATE-tests-A11", Guid.NewGuid().ToString());
            string tempPath = Path.Combine(tempDir, "save.json");
            try
            {
                Directory.CreateDirectory(tempDir);
                File.WriteAllText(tempPath, "{\"Version\":2,\"Day\":100,\"Hour\":5,\"Minute\":30,\"Money\":1500,\"Energy\":80,\"Hunger\":70,\"Thirst\":60,\"StudyXP\":50,\"IsSleeping\":false,\"IsWorking\":false,\"IsStudying\":false,\"WorkMinutesAccumulator\":0,\"StudyMinutesAccumulator\":0,\"Intelligence\":101.0,\"SavedAtUtc\":\"2026-06-15T12:00:00+00:00\"}");

                var loadClock = new GameClock();
                var loadPlayer = new PlayerState(loadClock);
                loadPlayer.DebugAddMoney(-900);
                int moneyBefore = loadPlayer.Money;
                int dayBefore = loadClock.Day;

                bool loaded = SaveManager.Load(loadClock, loadPlayer, tempPath);
                bool pass = !loaded && loadPlayer.Money == moneyBefore && loadClock.Day == dayBefore &&
                            Math.Abs(loadPlayer.Attributes.Intelligence - 10.0) < 0.000001;
                Console.WriteLine($"Attribute-A11: {pass} (Expected: True)");
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }

        // --- Attribute-A12: Offline Study Progression ---
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "LIFESTATE-tests-A12", Guid.NewGuid().ToString());
            string tempPath = Path.Combine(tempDir, "save.json");
            try
            {
                Directory.CreateDirectory(tempDir);
                DateTimeOffset baseTime = new DateTimeOffset(2026, 9, 9, 12, 0, 0, TimeSpan.Zero);

                var clock = new GameClock();
                var player = new PlayerState(clock);
                var gm = new GodMode(clock, player);
                gm.SetEnabled(true);
                gm.AdvanceDays(10 * 365);
                player.StartStudying();
                SaveManager.Save(clock, player, tempPath, baseTime);

                DateTimeOffset loadTime = baseTime.AddSeconds(150);
                var loadClock = new GameClock();
                var loadPlayer = new PlayerState(loadClock);
                bool loaded = SaveManager.Load(loadClock, loadPlayer, tempPath, loadTime);

                bool pass = loaded &&
                    loadPlayer.StudyXP == 100 &&
                    Math.Abs(loadPlayer.Attributes.Intelligence - 10.50) < 0.000001 &&
                    loadPlayer.IsStudying;
                Console.WriteLine($"Attribute-A12: {pass} (Expected: True)");
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }

        // --- Attribute-A13: Bulk vs Normal Study Equivalence ---
        {
            var clock1 = new GameClock();
            var p1 = new PlayerState(clock1);
            var gm1 = new GodMode(clock1, p1);
            gm1.SetEnabled(true);
            gm1.AdvanceDays(10 * 365);
            p1.StartStudying();
            p1.AdvanceSimulation(17);

            var clock2 = new GameClock();
            var p2 = new PlayerState(clock2);
            var gm2 = new GodMode(clock2, p2);
            gm2.SetEnabled(true);
            gm2.AdvanceDays(10 * 365);
            p2.StartStudying();
            p2.AdvanceSimulation(17);

            long remaining = 10001;
            while (remaining > 0)
            {
                int chunk = (int)Math.Min(remaining, 60);
                p1.AdvanceSimulation(chunk);
                remaining -= chunk;
            }

            p2.BulkAdvanceSimulation(10001, out long moneyEarned, out long xpEarned);
            p2.ApplyRewards(moneyEarned, xpEarned);

            bool pass = p1.StudyXP == p2.StudyXP &&
                Math.Abs(p1.Attributes.Intelligence - p2.Attributes.Intelligence) < 0.000001 &&
                p1.GetStudyMinutesAccumulator() == p2.GetStudyMinutesAccumulator() &&
                p1.Energy == p2.Energy &&
                p1.Hunger == p2.Hunger &&
                p1.Thirst == p2.Thirst &&
                p1.IsStudying == p2.IsStudying;
            Console.WriteLine($"Attribute-A13: {pass} (Expected: True)");
        }

        // --- Attribute-A14: Offline Intelligence Cap ---
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "LIFESTATE-tests-A14", Guid.NewGuid().ToString());
            string tempPath = Path.Combine(tempDir, "save.json");
            try
            {
                Directory.CreateDirectory(tempDir);
                DateTimeOffset baseTime = new DateTimeOffset(2026, 9, 9, 12, 0, 0, TimeSpan.Zero);

                var clock = new GameClock();
                var player = new PlayerState(clock);
                var gm = new GodMode(clock, player);
                gm.SetEnabled(true);
                gm.AdvanceDays(10 * 365);
                player.Attributes.AddIntelligence(89.98);
                player.StartStudying();
                SaveManager.Save(clock, player, tempPath, baseTime);

                DateTimeOffset loadTime = baseTime.AddSeconds(1650);
                var loadClock = new GameClock();
                var loadPlayer = new PlayerState(loadClock);
                bool loaded = SaveManager.Load(loadClock, loadPlayer, tempPath, loadTime);

                bool pass = loaded &&
                    Math.Abs(loadPlayer.Attributes.Intelligence - 100.0) < 0.000001 &&
                    loadPlayer.StudyXP >= 1000;
                Console.WriteLine($"Attribute-A14: {pass} (Expected: True)");
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }

        // --- GodMode-Attributes ---
        {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            player.Attributes.AddIntelligence(20.0);
            player.Attributes.AddFitness(30.0);
            player.Attributes.AddSocial(15.0);
            player.Attributes.AddDiscipline(5.0);
            player.Attributes.AddCreativity(25.0);
            int moneyBefore = player.Money;
            int xpBefore = player.StudyXP;
            int dayBefore = clock.Day;
            bool studying = player.IsStudying;

            gm.MaxAttributes();

            bool pass = Math.Abs(player.Attributes.Intelligence - 100.0) < 0.000001 &&
                        Math.Abs(player.Attributes.Fitness - 100.0) < 0.000001 &&
                        Math.Abs(player.Attributes.Social - 100.0) < 0.000001 &&
                        Math.Abs(player.Attributes.Discipline - 100.0) < 0.000001 &&
                        Math.Abs(player.Attributes.Creativity - 100.0) < 0.000001 &&
                        player.Money == moneyBefore &&
                        player.StudyXP == xpBefore &&
                        clock.Day == dayBefore &&
                        player.IsStudying == studying;
            Console.WriteLine($"GodMode-Attributes: {pass} (Expected: True)");
        }
    }

    private static void RunNeedPersistTests()
    {
        Console.WriteLine("\n--- LIFESTATE Need Persistence Regression Tests ---");

        void RunWithTempSave(Action<string> testAction)
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "LIFESTATE-tests-N", Guid.NewGuid().ToString());
            string tempSavePath = Path.Combine(tempDir, "save.json");
            try
            {
                Directory.CreateDirectory(tempDir);
                testAction(tempSavePath);
            }
            finally
            {
                if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            }
        }

        DateTimeOffset baseTime = new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);

        // --- NeedPersist-N1: Awake Partial Continuity ---
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.AdvanceSimulation(59); // Awake 59, Hunger 59, Thirst 59
            SaveManager.Save(clock, player, path, baseTime);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, baseTime);
            loadPlayer.AdvanceSimulation(1); // 59+1=60 -> Energy -1, Hunger -1, Thirst -2

            bool pass = loaded && loadPlayer.Energy == 99 && loadPlayer.Hunger == 99 && loadPlayer.Thirst == 98;
            Console.WriteLine($"NeedPersist-N1: {pass} (Expected: True)");
        });

        // --- NeedPersist-N2: Nontrivial Partial Values ---
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.AdvanceSimulation(15);
            // Save and verify accumulators restore exactly
            SaveManager.Save(clock, player, path, baseTime);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, baseTime);

            bool pass = loaded &&
                loadPlayer.GetAwakeMinutesAccumulator() == 15 &&
                loadPlayer.GetHungerMinutesAccumulator() == 15 &&
                loadPlayer.GetThirstMinutesAccumulator() == 15;
            Console.WriteLine($"NeedPersist-N2: {pass} (Expected: True)");
        });

        // --- NeedPersist-N3: Separate Awake/Sleeping Energy Remainders ---
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.AdvanceSimulation(30); // Awake 30
            player.StartSleeping();
            player.AdvanceSimulation(20); // Sleeping 20
            SaveManager.Save(clock, player, path, baseTime);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, baseTime);

            bool passRestored = loaded &&
                loadPlayer.GetAwakeMinutesAccumulator() == 30 &&
                loadPlayer.GetSleepingMinutesAccumulator() == 20;

            // Verify subsequent awake progression uses retained awake remainder
            loadPlayer.StopSleeping();
            loadPlayer.AdvanceSimulation(30); // 30+30=60 -> Energy -1

            bool passBehavior = loadPlayer.Energy == 99;
            Console.WriteLine($"NeedPersist-N3: {passRestored && passBehavior} (Expected: True)");
        });

        // --- NeedPersist-N4: Hunger/Thirst Persistence ---
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.AdvanceSimulation(45); // Hunger 45, Thirst 45
            SaveManager.Save(clock, player, path, baseTime);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, baseTime);

            bool passRestored = loaded &&
                loadPlayer.GetHungerMinutesAccumulator() == 45 &&
                loadPlayer.GetThirstMinutesAccumulator() == 45;

            // Advance 15 minutes to cross threshold (45+15=60)
            loadPlayer.AdvanceSimulation(15);

            bool passBehavior = loadPlayer.Hunger == 99 && loadPlayer.Thirst == 98;
            Console.WriteLine($"NeedPersist-N4: {passRestored && passBehavior} (Expected: True)");
        });

        // --- NeedPersist-N5: Old Version 2 Compatibility ---
        RunWithTempSave(path => {
            // V2 save WITHOUT need-accumulator fields (simulating pre-this-ticket save)
            File.WriteAllText(path, "{\"Version\":2,\"Day\":100,\"Hour\":5,\"Minute\":30,\"Money\":1500,\"Energy\":80,\"Hunger\":70,\"Thirst\":60,\"StudyXP\":50,\"IsSleeping\":false,\"IsWorking\":false,\"IsStudying\":false,\"WorkMinutesAccumulator\":0,\"StudyMinutesAccumulator\":0,\"SavedAtUtc\":\"2026-06-15T12:00:00+00:00\"}");

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            DateTimeOffset loadTime = new DateTimeOffset(2026, 6, 15, 12, 0, 0, TimeSpan.Zero);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            bool pass = loaded &&
                loadPlayer.GetAwakeMinutesAccumulator() == 0 &&
                loadPlayer.GetSleepingMinutesAccumulator() == 0 &&
                loadPlayer.GetHungerMinutesAccumulator() == 0 &&
                loadPlayer.GetThirstMinutesAccumulator() == 0;
            Console.WriteLine($"NeedPersist-N5: {pass} (Expected: True)");
        });

        // --- NeedPersist-N6: Invalid Accumulator Rejection ---
        RunWithTempSave(path => {
            // Test -1
            File.WriteAllText(path, "{\"Version\":2,\"Day\":0,\"Money\":1000,\"Energy\":100,\"Hunger\":100,\"Thirst\":100,\"AwakeMinutesAccumulator\":-1,\"SavedAtUtc\":\"2026-06-15T12:00:00+00:00\"}");
            var clock1 = new GameClock();
            var player1 = new PlayerState(clock1);
            player1.DebugAddMoney(-900);
            int moneyBefore = player1.Money;
            bool loadedNeg = SaveManager.Load(clock1, player1, path, new DateTimeOffset(2026, 6, 15, 12, 0, 0, TimeSpan.Zero));
            bool passNeg = !loadedNeg && player1.Money == moneyBefore;

            // Test 60
            File.WriteAllText(path, "{\"Version\":2,\"Day\":0,\"Money\":1000,\"Energy\":100,\"Hunger\":100,\"Thirst\":100,\"HungerMinutesAccumulator\":60,\"SavedAtUtc\":\"2026-06-15T12:00:00+00:00\"}");
            var clock2 = new GameClock();
            var player2 = new PlayerState(clock2);
            int moneyBefore2 = player2.Money;
            bool loaded60 = SaveManager.Load(clock2, player2, path, new DateTimeOffset(2026, 6, 15, 12, 0, 0, TimeSpan.Zero));
            bool pass60 = !loaded60 && player2.Money == moneyBefore2;

            bool pass = passNeg && pass60;
            Console.WriteLine($"NeedPersist-N6: {pass} (Expected: True)");
        });

        // --- NeedPersist-N7: Offline Progression Uses Saved Remainder ---
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.AdvanceSimulation(56); // Awake 56, Hunger 56, Thirst 56
            SaveManager.Save(clock, player, path, baseTime);

            // 4 game minutes offline = 1.0 real second
            DateTimeOffset loadTime = baseTime.AddSeconds(1.0);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            // 56+4=60 -> Energy -1, Hunger -1, Thirst -2
            // Remainders: 0, 0, 0
            bool pass = loaded &&
                loadPlayer.Energy == 99 && loadPlayer.Hunger == 99 && loadPlayer.Thirst == 98 &&
                loadPlayer.GetAwakeMinutesAccumulator() == 0 &&
                loadPlayer.GetHungerMinutesAccumulator() == 0 &&
                loadPlayer.GetThirstMinutesAccumulator() == 0;
            Console.WriteLine($"NeedPersist-N7: {pass} (Expected: True)");
        });

        // --- NeedPersist-N8: Final Commit Preserves Post-Offline Remainder ---
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            player.AdvanceSimulation(17); // Awake 17, Hunger 17, Thirst 17
            SaveManager.Save(clock, player, path, baseTime);

            // 100 game minutes offline = 25 real seconds
            // 17 + 100 = 117 -> completed 1 hour, remainder 57
            DateTimeOffset loadTime = baseTime.AddSeconds(25);
            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, loadTime);

            bool pass = loaded &&
                loadPlayer.GetAwakeMinutesAccumulator() == 57 &&
                loadPlayer.GetHungerMinutesAccumulator() == 57 &&
                loadPlayer.GetThirstMinutesAccumulator() == 57;
            Console.WriteLine($"NeedPersist-N8: {pass} (Expected: True)");
        });

        // --- NeedPersist-N9: Save/Load Round Trip All Six Accumulators ---
        RunWithTempSave(path => {
            var clock = new GameClock();
            var player = new PlayerState(clock);
            var gm = new GodMode(clock, player);
            gm.SetEnabled(true);
            gm.AdvanceDays(20 * 365); // Adult
            player.StartWorking();
            player.StartStudying(); // Rejected: mutually exclusive with Work
            player.StopWorking();
            player.StartStudying();
            player.AdvanceSimulation(20); // Study 20, Awake 20, Hunger 20, Thirst 20
            player.StopStudying();
            player.StartWorking();
            player.AdvanceSimulation(15); // Work 15, Awake 15 (35 total), Hunger 15 (35), Thirst 15 (35)
            // Now: awake=35, hunger=35, thirst=35, work=15, study=20
            // Set a sleeping remainder: start sleeping
            player.StopWorking();
            player.StartSleeping();
            player.AdvanceSimulation(10); // Sleeping 10
            player.StopSleeping();

            SaveManager.Save(clock, player, path, baseTime);

            var loadClock = new GameClock();
            var loadPlayer = new PlayerState(loadClock);
            bool loaded = SaveManager.Load(loadClock, loadPlayer, path, baseTime);

            bool pass = loaded &&
                loadPlayer.GetAwakeMinutesAccumulator() == player.GetAwakeMinutesAccumulator() &&
                loadPlayer.GetSleepingMinutesAccumulator() == player.GetSleepingMinutesAccumulator() &&
                loadPlayer.GetHungerMinutesAccumulator() == player.GetHungerMinutesAccumulator() &&
                loadPlayer.GetThirstMinutesAccumulator() == player.GetThirstMinutesAccumulator() &&
                loadPlayer.GetWorkMinutesAccumulator() == player.GetWorkMinutesAccumulator() &&
                loadPlayer.GetStudyMinutesAccumulator() == player.GetStudyMinutesAccumulator();
            Console.WriteLine($"NeedPersist-N9: {pass} (Expected: True)");
        });
    }
}
