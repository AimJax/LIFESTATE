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
        var saveClock = new GameClock();
        var savePlayer = new PlayerState(saveClock);
        saveClock.AdvanceSeconds(60);
        savePlayer.UpdateEnergy(30);
        savePlayer.StartWorking();
        savePlayer.AdvanceSimulation(60);

        SaveManager.Save(saveClock, savePlayer);

        var loadClock = new GameClock();
        var loadPlayer = new PlayerState(loadClock);
        bool loaded = SaveManager.Load(loadClock, loadPlayer);

        Console.WriteLine($"Load successful: {loaded} (Expected: True)");
        Console.WriteLine($"Day: {loadClock.Day} (Expected: {saveClock.Day}), Time: {loadClock.Hour}:{loadClock.Minute} (Expected: {saveClock.Hour}:{saveClock.Minute})");
        Console.WriteLine($"Money: {loadPlayer.Money} (Expected: {savePlayer.Money}), IsWorking: {loadPlayer.IsWorking} (Expected: {savePlayer.IsWorking})");
    }
}
