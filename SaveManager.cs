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
            Version = 4,
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
            AwakeMinutesAccumulator = player.GetAwakeMinutesAccumulator(),
            SleepingMinutesAccumulator = player.GetSleepingMinutesAccumulator(),
            HungerMinutesAccumulator = player.GetHungerMinutesAccumulator(),
            ThirstMinutesAccumulator = player.GetThirstMinutesAccumulator(),
            AcademicsExperience = player.Skills.Academics.Experience,
            EducationStatus = (int)player.Education.Status,
            PrimaryGrade = player.Education.PrimaryGrade,
            EducationProgress = player.Education.EducationProgress,
            SchoolYearStartDay = player.Education.SchoolYearStartDay,
            Confidence = player.Traits.Confidence,
            Curiosity = player.Traits.Curiosity,
            Patience = player.Traits.Patience,
            Ambition = player.Traits.Ambition,
            Empathy = player.Traits.Empathy,
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

            if (saveData == null || (saveData.Version != 2 && saveData.Version != 3 && saveData.Version != 4)) return false;

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
                saveData.AwakeMinutesAccumulator < 0 || saveData.AwakeMinutesAccumulator >= 60 ||
                saveData.SleepingMinutesAccumulator < 0 || saveData.SleepingMinutesAccumulator >= 60 ||
                saveData.HungerMinutesAccumulator < 0 || saveData.HungerMinutesAccumulator >= 60 ||
                saveData.ThirstMinutesAccumulator < 0 || saveData.ThirstMinutesAccumulator >= 60 ||
                (saveData.IsSleeping ? 1 : 0) + (saveData.IsWorking ? 1 : 0) + (saveData.IsStudying ? 1 : 0) > 1 ||
                saveData.SavedAtUtc == DateTimeOffset.MinValue)
            {
                return false;
            }

            // Validate AcademicsExperience
            if (saveData.AcademicsExperience < 0 || saveData.AcademicsExperience > SkillProgress.MaxExperience)
                return false;

            // Validate attribute values
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

            // Validate Education if version 3+
            EducationStatus eduStatus = EducationStatus.NotEnrolled;
            int eduGrade = 0;
            int eduProgress = 0;
            long eduStartDay = 0;
            if (saveData.Version >= 3)
            {
                eduStatus = (EducationStatus)saveData.EducationStatus;
                eduGrade = saveData.PrimaryGrade;
                eduProgress = saveData.EducationProgress;
                eduStartDay = saveData.SchoolYearStartDay;

                if (!ValidateEducation(eduStatus, eduGrade, eduProgress, eduStartDay, saveData.Day))
                    return false;
            }

            // Validate Traits if version 4 (V3/V2 saves have no trait fields; defaults apply)
            double traitConfidence = 50.0;
            double traitCuriosity = 50.0;
            double traitPatience = 50.0;
            double traitAmbition = 50.0;
            double traitEmpathy = 50.0;
            if (saveData.Version == 4)
            {
                if (!IsValidTraitValue(saveData.Confidence) ||
                    !IsValidTraitValue(saveData.Curiosity) ||
                    !IsValidTraitValue(saveData.Patience) ||
                    !IsValidTraitValue(saveData.Ambition) ||
                    !IsValidTraitValue(saveData.Empathy))
                {
                    return false;
                }

                traitConfidence = saveData.Confidence;
                traitCuriosity = saveData.Curiosity;
                traitPatience = saveData.Patience;
                traitAmbition = saveData.Ambition;
                traitEmpathy = saveData.Empathy;
            }

            // Transactional Load: Create clones for validation
            var tempClock = new GameClock();
            tempClock.Restore(saveData.Day, saveData.Hour, saveData.Minute);
            var tempPlayer = new PlayerState(tempClock);
            tempPlayer.Restore(saveData.Money, saveData.Energy, saveData.Hunger, saveData.Thirst, saveData.StudyXP,
                saveData.IsSleeping, saveData.IsWorking, saveData.IsStudying,
                saveData.AwakeMinutesAccumulator, saveData.SleepingMinutesAccumulator,
                saveData.HungerMinutesAccumulator, saveData.ThirstMinutesAccumulator,
                saveData.WorkMinutesAccumulator, saveData.StudyMinutesAccumulator);
            tempPlayer.Attributes.Restore(attrIntelligence, attrFitness, attrSocial, attrDiscipline, attrCreativity);
            tempPlayer.Skills.Academics.Restore(saveData.AcademicsExperience);
            tempPlayer.Education.Restore(eduStatus, eduGrade, eduProgress, eduStartDay);
            tempPlayer.Traits.Restore(traitConfidence, traitCuriosity, traitPatience, traitAmbition, traitEmpathy);

            // Offline Progression Calculation
            DateTimeOffset currentTime = nowUtc ?? DateTimeOffset.UtcNow;
            long elapsedSeconds = (long)(currentTime - saveData.SavedAtUtc).TotalSeconds;
            if (elapsedSeconds < 0) elapsedSeconds = 0;

            if (elapsedSeconds > 0)
            {
                long elapsedMinutes = elapsedSeconds * GameClock.MinutesPerRealSecond;

                try
                {
                    tempClock.AdvanceGameMinutes(elapsedMinutes);
                }
                catch (OverflowException)
                {
                    return false;
                }

                if (!tempPlayer.PreflightWorkAndStudy(elapsedMinutes, out _, out _))
                {
                    return false;
                }

                tempPlayer.BulkAdvanceSimulation(elapsedMinutes, out long moneyEarned, out long xpEarned);
                tempPlayer.ApplyRewards(moneyEarned, xpEarned);
                // Evaluate education after offline progression (clock has advanced)
                tempPlayer.Education.EvaluateProgression(tempClock.Day);
            }

            // Commit to live objects
            clock.Restore(tempClock.Day, tempClock.Hour, tempClock.Minute);
            player.Restore(tempPlayer.Money, tempPlayer.Energy, tempPlayer.Hunger, tempPlayer.Thirst, tempPlayer.StudyXP,
                tempPlayer.IsSleeping, tempPlayer.IsWorking, tempPlayer.IsStudying,
                tempPlayer.GetAwakeMinutesAccumulator(), tempPlayer.GetSleepingMinutesAccumulator(),
                tempPlayer.GetHungerMinutesAccumulator(), tempPlayer.GetThirstMinutesAccumulator(),
                tempPlayer.GetWorkMinutesAccumulator(), tempPlayer.GetStudyMinutesAccumulator());
            player.Attributes.Restore(tempPlayer.Attributes.Intelligence, tempPlayer.Attributes.Fitness, tempPlayer.Attributes.Social, tempPlayer.Attributes.Discipline, tempPlayer.Attributes.Creativity);
            player.Skills.Academics.Restore(tempPlayer.Skills.Academics.Experience);
            player.Education.Restore(tempPlayer.Education.Status, tempPlayer.Education.PrimaryGrade, tempPlayer.Education.EducationProgress, tempPlayer.Education.SchoolYearStartDay);
            player.Traits.Restore(tempPlayer.Traits.Confidence, tempPlayer.Traits.Curiosity, tempPlayer.Traits.Patience, tempPlayer.Traits.Ambition, tempPlayer.Traits.Empathy);

            return true;
        }
        catch
        {
            return false;
        }
    }

    private static bool ValidateEducation(EducationStatus status, int grade, int progress, long startDay, int currentDay)
    {
        if (startDay < 0 || startDay > currentDay) return false;

        if (status == EducationStatus.NotEnrolled)
            return grade == 0 && progress == 0 && startDay == 0;

        if (status == EducationStatus.PrimarySchool)
            return grade >= 1 && grade <= 6 && progress >= 0 && progress <= 100;

        if (status == EducationStatus.CompletedPrimary)
            return grade == 6 && progress == 100;

        return false;
    }

    private static bool IsValidTraitValue(double value)
    {
        return !double.IsNaN(value) && !double.IsInfinity(value) && value >= 0.0 && value <= 100.0;
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