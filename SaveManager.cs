using System;
using System.IO;
using System.Text.Json;

namespace Lifestate;

public static class SaveManager
{
    private static readonly string SaveDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LIFESTATE");
    private static readonly string SaveFilePath = Path.Combine(SaveDirectory, "save.json");

    public static void Save(GameClock clock, PlayerState player, string? path = null, DateTimeOffset? nowUtc = null)
    {
        var saveData = new SaveData
        {
            Version = 2,
            Day = clock.Day,
            Hour = clock.Hour,
            Minute = clock.Minute,
            Money = player.Money,
            Energy = player.Energy,
            Hunger = player.Hunger,
            Thirst = player.Thirst,
            StudyXP = player.StudyXP,
            IsSleeping = player.IsSleeping,
            IsWorking = player.IsWorking,
            IsStudying = player.IsStudying,
            WorkMinutesAccumulator = player.GetWorkMinutesAccumulator(),
            StudyMinutesAccumulator = player.GetStudyMinutesAccumulator(),
            SavedAtUtc = nowUtc ?? DateTimeOffset.UtcNow
        };

        string targetPath = path ?? SaveFilePath;
        string? targetDir = Path.GetDirectoryName(targetPath);
        if (targetDir != null && !Directory.Exists(targetDir))
        {
            Directory.CreateDirectory(targetDir);
        }

        string json = JsonSerializer.Serialize(saveData);
        File.WriteAllText(targetPath, json);
    }

    public static bool Load(GameClock clock, PlayerState player, string? path = null, DateTimeOffset? nowUtc = null)
    {
        string targetPath = path ?? SaveFilePath;
        if (!File.Exists(targetPath)) return false;

        try
        {
            string json = File.ReadAllText(targetPath);
            var saveData = JsonSerializer.Deserialize<SaveData>(json);

            if (saveData == null || saveData.Version != 2) return false;

            // Strict Validation
            if (saveData.Day < 0 ||
                saveData.Hour < 0 || saveData.Hour > 23 ||
                saveData.Minute < 0 || saveData.Minute > 59 ||
                saveData.Energy < 0 || saveData.Energy > 100 ||
                saveData.Hunger < 0 || saveData.Hunger > 100 ||
                saveData.Thirst < 0 || saveData.Thirst > 100 ||
                saveData.Money < 0 || saveData.StudyXP < 0 ||
                saveData.WorkMinutesAccumulator < 0 || saveData.WorkMinutesAccumulator >= 60 ||
                saveData.StudyMinutesAccumulator < 0 || saveData.StudyMinutesAccumulator >= 60 ||
                (saveData.IsSleeping ? 1 : 0) + (saveData.IsWorking ? 1 : 0) + (saveData.IsStudying ? 1 : 0) > 1 ||
                saveData.SavedAtUtc == DateTimeOffset.MinValue)
            {
                return false;
            }

            // Transactional Restore
            clock.Restore(saveData.Day, saveData.Hour, saveData.Minute);
            player.Restore(saveData.Money, saveData.Energy, saveData.Hunger, saveData.Thirst, saveData.StudyXP, saveData.IsSleeping, saveData.IsWorking, saveData.IsStudying, saveData.WorkMinutesAccumulator, saveData.StudyMinutesAccumulator);
            
            // Offline Progression
            DateTimeOffset currentTime = nowUtc ?? DateTimeOffset.UtcNow;
            long elapsedSeconds = (long)(currentTime - saveData.SavedAtUtc).TotalSeconds;
            if (elapsedSeconds < 0) elapsedSeconds = 0;

            if (elapsedSeconds > 0)
            {
                // Bulk chunking to avoid huge simulation ticks
                long elapsedMinutes = elapsedSeconds * GameClock.MinutesPerRealSecond;
                const int MaxMinutesPerTick = 60 * 24; // 1 day chunk
                
                long remainingMinutes = elapsedMinutes;
                while (remainingMinutes > 0)
                {
                    int chunk = (int)Math.Min(remainingMinutes, MaxMinutesPerTick);
                    player.AdvanceSimulation(chunk);
                    remainingMinutes -= chunk;
                }
                
                // Clock handles rollover logic using long-safe method
                clock.AdvanceGameMinutes(elapsedMinutes);
            }

            return true;
        }
        catch
        {
            return false;
        }
    }
}
