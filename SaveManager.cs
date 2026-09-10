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
            Intelligence = player.Attributes.Intelligence,
            Fitness = player.Attributes.Fitness,
            Social = player.Attributes.Social,
            Discipline = player.Attributes.Discipline,
            Creativity = player.Attributes.Creativity,
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

            // Strict Validation — basic fields
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

            // Validate attribute values — nulls are acceptable (old V2 compat), present values must be finite and in [0, 100]
            double attrIntelligence = GetValidatedAttribute(saveData.Intelligence, out bool attrValid);
            if (!attrValid) return false;
            double attrFitness = GetValidatedAttribute(saveData.Fitness, out attrValid);
            if (!attrValid) return false;
            double attrSocial = GetValidatedAttribute(saveData.Social, out attrValid);
            if (!attrValid) return false;
            double attrDiscipline = GetValidatedAttribute(saveData.Discipline, out attrValid);
            if (!attrValid) return false;
            double attrCreativity = GetValidatedAttribute(saveData.Creativity, out attrValid);
            if (!attrValid) return false;

            // Transactional Load: Create clones for validation
            var tempClock = new GameClock();
            tempClock.Restore(saveData.Day, saveData.Hour, saveData.Minute);
            var tempPlayer = new PlayerState(tempClock);
            tempPlayer.Restore(saveData.Money, saveData.Energy, saveData.Hunger, saveData.Thirst, saveData.StudyXP, saveData.IsSleeping, saveData.IsWorking, saveData.IsStudying, saveData.WorkMinutesAccumulator, saveData.StudyMinutesAccumulator);
            tempPlayer.Attributes.Restore(attrIntelligence, attrFitness, attrSocial, attrDiscipline, attrCreativity);

            // Offline Progression Calculation
            DateTimeOffset currentTime = nowUtc ?? DateTimeOffset.UtcNow;
            long elapsedSeconds = (long)(currentTime - saveData.SavedAtUtc).TotalSeconds;
            if (elapsedSeconds < 0) elapsedSeconds = 0;

            if (elapsedSeconds > 0)
            {
                long elapsedMinutes = elapsedSeconds * GameClock.MinutesPerRealSecond;

                // Preflight clock overflow
                try
                {
                    tempClock.AdvanceGameMinutes(elapsedMinutes);
                }
                catch (OverflowException)
                {
                    return false;
                }

                // Preflight Money/XP overflow
                if (!tempPlayer.PreflightWorkAndStudy(elapsedMinutes, out _, out _))
                {
                    return false;
                }

                // Apply offline progression to temp objects
                tempPlayer.BulkAdvanceSimulation(elapsedMinutes, out long moneyEarned, out long xpEarned);
                tempPlayer.ApplyRewards(moneyEarned, xpEarned);
            }

            // Only if we get here do we modify the actual objects
            clock.Restore(tempClock.Day, tempClock.Hour, tempClock.Minute);
            player.Restore(tempPlayer.Money, tempPlayer.Energy, tempPlayer.Hunger, tempPlayer.Thirst, tempPlayer.StudyXP, tempPlayer.IsSleeping, tempPlayer.IsWorking, tempPlayer.IsStudying, tempPlayer.GetWorkMinutesAccumulator(), tempPlayer.GetStudyMinutesAccumulator());
            player.Attributes.Restore(tempPlayer.Attributes.Intelligence, tempPlayer.Attributes.Fitness, tempPlayer.Attributes.Social, tempPlayer.Attributes.Discipline, tempPlayer.Attributes.Creativity);

            return true;
        }
        catch
        {
            return false;
        }
    }

    private static double GetValidatedAttribute(double? value, out bool valid)
    {
        valid = true;
        if (value == null) return 10.0;
        double v = value.Value;
        if (double.IsNaN(v) || double.IsInfinity(v) || v < 0.0 || v > 100.0)
        {
            valid = false;
            return 0.0;
        }
        return v;
    }
}