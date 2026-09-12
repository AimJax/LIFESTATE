using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace Lifestate;

/// <summary>
/// Test-only bridge that lets the Godot/GDScript suite prove it shares one save
/// format with this C# reference build. Nothing here is gameplay code and no
/// interactive path reaches it: it runs only when the executable is passed one of
/// the flags below, exactly like <c>--test</c>.
///
/// <code>
/// Lifestate.exe --save-fixture &lt;savePath&gt; [summaryPath]
/// Lifestate.exe --load-fixture &lt;savePath&gt;
/// Lifestate.exe --verify-fixture &lt;savePath&gt; &lt;summaryPath&gt; [offlineSeconds]
/// Lifestate.exe --reject-fixture &lt;savePath&gt;
/// </code>
///
/// Paired with <c>Lifestate.Godot/tests/run_save_interchange.gd</c>.
/// </summary>
public static class SaveInterchangeHarness
{
    /// <summary>
    /// The instant used by every fixture save and load. Loading with
    /// now == SavedAtUtc means offline progression is exactly zero, so summaries
    /// are directly comparable.
    /// </summary>
    private static readonly DateTimeOffset FixedStamp = DateTimeOffset.FromUnixTimeSeconds(1800000000);

    /// <returns>true when the arguments were a harness invocation.</returns>
    public static bool TryRun(string[] args)
    {
        if (args.Length < 2) return false;

        switch (args[0])
        {
            case "--save-fixture":
                RunSaveFixture(args);
                return true;
            case "--load-fixture":
                RunLoadFixture(args[1]);
                return true;
            case "--verify-fixture":
                if (args.Length < 3) return false;
                RunVerifyFixture(args[1], args[2], args.Length >= 4 ? double.Parse(args[3]) : 0.0);
                return true;
            case "--reject-fixture":
                RunRejectFixture(args[1]);
                return true;
            default:
                return false;
        }
    }

    private static void RunSaveFixture(string[] args)
    {
        var clock = new GameClock();
        var player = new PlayerState(clock);
        BuildFixture(clock, player);
        SaveManager.Save(clock, player, args[1], FixedStamp);

        string summary = Summary(clock, player);
        if (args.Length >= 3) File.WriteAllText(args[2], summary);
        Console.WriteLine("SUMMARY:" + summary);
    }

    private static void RunLoadFixture(string path)
    {
        var clock = new GameClock();
        var player = new PlayerState(clock);
        bool loaded = SaveManager.Load(clock, player, path, FixedStamp);
        Console.WriteLine("LOADED:" + (loaded ? "1" : "0"));
        Console.WriteLine("SUMMARY:" + Summary(clock, player));
    }

    /// <summary>
    /// Loads a save the GDScript port wrote and compares it against a reference
    /// summary the port produced. Exits non-zero on any field mismatch.
    /// </summary>
    private static void RunVerifyFixture(string savePath, string summaryPath, double offlineSeconds)
    {
        var clock = new GameClock();
        var player = new PlayerState(clock);
        bool loaded = SaveManager.Load(clock, player, savePath, FixedStamp.AddSeconds(offlineSeconds));
        Console.WriteLine("LOADED:" + (loaded ? "1" : "0"));
        if (!loaded)
        {
            Environment.ExitCode = 1;
            return;
        }

        var actual = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(Summary(clock, player))!;
        var expected = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(File.ReadAllText(summaryPath))!;

        int mismatches = 0;
        foreach (var entry in expected)
        {
            if (!actual.TryGetValue(entry.Key, out var value))
            {
                Console.WriteLine($"MISMATCH {entry.Key}: missing (expected {entry.Value.GetRawText()})");
                mismatches++;
            }
            else if (value.GetRawText() != entry.Value.GetRawText())
            {
                Console.WriteLine($"MISMATCH {entry.Key}: {value.GetRawText()} != {entry.Value.GetRawText()}");
                mismatches++;
            }
        }
        foreach (var entry in actual)
        {
            if (!expected.ContainsKey(entry.Key))
            {
                Console.WriteLine($"MISMATCH {entry.Key}: unexpected key");
                mismatches++;
            }
        }

        Console.WriteLine("MISMATCHES:" + mismatches);
        Environment.ExitCode = mismatches == 0 ? 0 : 1;
    }

    /// <summary>
    /// A save the current schema cannot accept must be refused without disturbing
    /// the running game.
    /// </summary>
    private static void RunRejectFixture(string path)
    {
        var clock = new GameClock();
        var player = new PlayerState(clock);
        clock.AdvanceSeconds(600);
        player.AdvanceSimulation(2400);

        long dayBefore = clock.Day;
        int moneyBefore = player.Money;
        int energyBefore = player.Energy;

        bool loaded = SaveManager.Load(clock, player, path, FixedStamp);
        bool untouched = clock.Day == dayBefore && player.Money == moneyBefore && player.Energy == energyBefore;

        Console.WriteLine("LOADED:" + (loaded ? "1" : "0"));
        Console.WriteLine("UNTOUCHED:" + (untouched ? "1" : "0"));
        Environment.ExitCode = loaded || !untouched ? 1 : 0;
    }

    /// <summary>
    /// Deterministic state exercising every persisted subsystem: needs and
    /// accumulators, all four activities, play hours, education, family,
    /// relationships, resolved event history and a pending event.
    /// </summary>
    private static void BuildFixture(GameClock clock, PlayerState player)
    {
        // Age 4, then 10 completed Play hours -> Broken Toy becomes eligible.
        Advance(clock, player, 4 * 365 * 360);
        player.StartPlaying();
        Advance(clock, player, 150);
        player.StopPlaying();
        Resolve(player, "childhood.broken_toy", "try_fix");

        // Age 6, enroll, resolve First Day of School.
        Advance(clock, player, 2 * 365 * 360);
        player.EnrollPrimarySchool();
        Resolve(player, "childhood.first_day_school", "introduce_yourself");

        // Study, then family time, then top the needs up a little.
        player.StartStudying();
        Advance(clock, player, 225);
        player.StopStudying();

        player.StartFamilyTime();
        Advance(clock, player, 60);
        player.StopFamilyTime();

        player.Eat(30);
        player.Drink(25);

        // Age 8 -> Found Money becomes eligible and is deliberately left pending.
        Advance(clock, player, 2 * 365 * 360);

        // An odd 17-second step (68 game minutes) leaves non-zero sub-hour
        // remainders behind, which a faithful port must persist.
        Advance(clock, player, 17);
    }

    /// <summary>Mirrors GameService._step_seconds: 1 real second = 4 game minutes.</summary>
    private static void Advance(GameClock clock, PlayerState player, int realSeconds)
    {
        clock.AdvanceSeconds(realSeconds);
        player.AdvanceSimulation(realSeconds * 4);
    }

    private static void Resolve(PlayerState player, string eventId, string choiceId)
    {
        if (player.Events.CurrentEvent?.EventId != eventId)
            throw new InvalidOperationException(
                $"expected pending '{eventId}', got '{player.Events.CurrentEvent?.EventId ?? "<none>"}'");
        if (!player.ResolveEventChoice(choiceId))
            throw new InvalidOperationException($"failed to resolve '{eventId}' with '{choiceId}'");
    }

    /// <summary>
    /// Integer-only summary so C# and GDScript emit byte-identical JSON: doubles
    /// are scaled by 100 and rounded away from zero.
    /// </summary>
    private static string Summary(GameClock clock, PlayerState player)
    {
        static int Scaled(double value) => (int)Math.Round(value * 100, MidpointRounding.AwayFromZero);

        var data = new Dictionary<string, object>
        {
            ["Day"] = clock.Day,
            ["Hour"] = clock.Hour,
            ["Minute"] = clock.Minute,
            ["Age"] = player.Age,
            ["Money"] = player.Money,
            ["Energy"] = player.Energy,
            ["Hunger"] = player.Hunger,
            ["Thirst"] = player.Thirst,
            ["StudyXP"] = player.StudyXP,
            ["IsSleeping"] = player.IsSleeping ? 1 : 0,
            ["IsWorking"] = player.IsWorking ? 1 : 0,
            ["IsStudying"] = player.IsStudying ? 1 : 0,
            ["IsPlaying"] = player.IsPlaying ? 1 : 0,
            ["IsFamilyTime"] = player.IsSpendingFamilyTime ? 1 : 0,
            ["AwakeAcc"] = player.GetAwakeMinutesAccumulator(),
            ["SleepingAcc"] = player.GetSleepingMinutesAccumulator(),
            ["HungerAcc"] = player.GetHungerMinutesAccumulator(),
            ["ThirstAcc"] = player.GetThirstMinutesAccumulator(),
            ["WorkAcc"] = player.GetWorkMinutesAccumulator(),
            ["StudyAcc"] = player.GetStudyMinutesAccumulator(),
            ["PlayAcc"] = player.GetPlayMinutesAccumulator(),
            ["FamilyAcc"] = player.GetFamilyTimeMinutesAccumulator(),
            ["AcademicsXP"] = Scaled(player.Skills.Academics.Experience),
            ["AcademicsLevel"] = player.Skills.Academics.Level,
            ["EducationStatus"] = (int)player.Education.Status,
            ["PrimaryGrade"] = player.Education.PrimaryGrade,
            ["EducationProgress"] = player.Education.EducationProgress,
            ["SchoolYearStartDay"] = player.Education.SchoolYearStartDay,
            ["TotalPlayHours"] = player.TotalPlayHours,
            ["HistoryCount"] = player.Events.History.Count,
            ["PendingEvent"] = player.Events.CurrentEvent?.EventId ?? "",
            ["MotherName"] = player.Family.Mother.Name,
            ["MotherAge"] = player.Family.Mother.GetAge(clock),
            ["MotherCloseness"] = Scaled(player.Relationships.MotherRelationship.Closeness),
            ["FatherName"] = player.Family.Father.Name,
            ["FatherAge"] = player.Family.Father.GetAge(clock),
            ["FatherCloseness"] = Scaled(player.Relationships.FatherRelationship.Closeness),
            ["Intelligence"] = Scaled(player.Attributes.Intelligence),
            ["Fitness"] = Scaled(player.Attributes.Fitness),
            ["Social"] = Scaled(player.Attributes.Social),
            ["Discipline"] = Scaled(player.Attributes.Discipline),
            ["Creativity"] = Scaled(player.Attributes.Creativity),
            ["Confidence"] = Scaled(player.Traits.Confidence),
            ["Curiosity"] = Scaled(player.Traits.Curiosity),
            ["Patience"] = Scaled(player.Traits.Patience),
            ["Ambition"] = Scaled(player.Traits.Ambition),
            ["Empathy"] = Scaled(player.Traits.Empathy),
        };

        return JsonSerializer.Serialize(data);
    }
}
