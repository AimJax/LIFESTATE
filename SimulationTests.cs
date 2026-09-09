using System;
using Lifestate;
using System.IO;
using System.Text.Json;

namespace Lifestate;

public static class SimulationTests
{
    private static void RunWithTempSave(Action<string> testAction)
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

    public static void RunTests()
    {
        Console.WriteLine("--- SIMULATION TESTS STARTING ---");
        try
        {
            // 1. Missing SavedAtUtc
            RunWithTempSave(path => {
                File.WriteAllText(path, "{\"Version\":2, \"Day\":0}");
                bool loaded = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), path);
                Console.WriteLine($"1. Missing SavedAtUtc: {loaded == false}");
            });

            // 2. MinValue SavedAtUtc
            RunWithTempSave(path => {
                var saveData = new { Version = 2, SavedAtUtc = DateTimeOffset.MinValue };
                File.WriteAllText(path, JsonSerializer.Serialize(saveData));
                bool loaded = SaveManager.Load(new GameClock(), new PlayerState(new GameClock()), path);
                Console.WriteLine($"2. MinValue SavedAtUtc: {loaded == false}");
            });

            // 3. Future SavedAtUtc
            RunWithTempSave(path => {
                var clock = new GameClock();
                var player = new PlayerState(clock);
                SaveManager.Save(clock, player, path, DateTimeOffset.UtcNow.AddMinutes(10));
                var loadClock = new GameClock();
                var loadPlayer = new PlayerState(loadClock);
                bool loaded = SaveManager.Load(loadClock, loadPlayer, path, DateTimeOffset.UtcNow);
                Console.WriteLine($"3. Future SavedAtUtc: {loaded == false}");
            });

            // 4. 1 Hour Offline
            RunWithTempSave(path => {
                var clock = new GameClock();
                var player = new PlayerState(clock);
                SaveManager.Save(clock, player, path, DateTimeOffset.UtcNow.AddHours(-1));
                var loadClock = new GameClock();
                var loadPlayer = new PlayerState(loadClock);
                SaveManager.Load(loadClock, loadPlayer, path, DateTimeOffset.UtcNow);
                Console.WriteLine($"4. 1 Hour Offline: {loadClock.Hour == 4}");
            });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Tests failed: {ex.Message}");
        }
    }
}
