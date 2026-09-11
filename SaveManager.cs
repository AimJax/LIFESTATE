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
            Version = 7,
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
            IsPlaying = player.IsPlaying,
            IsSpendingFamilyTime = player.IsSpendingFamilyTime,
            WorkMinutesAccumulator = player.GetWorkMinutesAccumulator(),
            StudyMinutesAccumulator = player.GetStudyMinutesAccumulator(),
            AwakeMinutesAccumulator = player.GetAwakeMinutesAccumulator(),
            SleepingMinutesAccumulator = player.GetSleepingMinutesAccumulator(),
            HungerMinutesAccumulator = player.GetHungerMinutesAccumulator(),
            ThirstMinutesAccumulator = player.GetThirstMinutesAccumulator(),
            PlayMinutesAccumulator = player.GetPlayMinutesAccumulator(),
            FamilyTimeMinutesAccumulator = player.GetFamilyTimeMinutesAccumulator(),
            AcademicsExperience = player.Skills.Academics.Experience,
            EducationStatus = (int)player.Education.Status,
            PrimaryGrade = player.Education.PrimaryGrade,
            EducationProgress = player.Education.EducationProgress,
            SchoolYearStartDay = player.Education.SchoolYearStartDay,
            TotalPlayHours = player.TotalPlayHours,
            CurrentEventId = player.Events.CurrentEvent?.EventId,
            CurrentEventTriggeredDay = player.Events.CurrentEvent?.TriggeredDay ?? 0,
            EventHistory = player.Events.History.Select(h => new EventHistorySaveData
            {
                EventId = h.EventId,
                ChoiceId = h.ChoiceId,
                TriggeredDay = h.TriggeredDay,
                ResolvedDay = h.ResolvedDay
            }).ToList(),
            MotherId = player.Family.Mother.Id,
            MotherName = player.Family.Mother.Name,
            MotherBirthDay = player.Family.Mother.BirthDay,
            FatherId = player.Family.Father.Id,
            FatherName = player.Family.Father.Name,
            FatherBirthDay = player.Family.Father.BirthDay,
            MotherRelationshipPersonId = player.Relationships.MotherRelationship.PersonId,
            MotherCloseness = player.Relationships.MotherRelationship.Closeness,
            FatherRelationshipPersonId = player.Relationships.FatherRelationship.PersonId,
            FatherCloseness = player.Relationships.FatherRelationship.Closeness,
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

            if (saveData == null || (saveData.Version != 2 && saveData.Version != 3 && saveData.Version != 4 && saveData.Version != 5 && saveData.Version != 6 && saveData.Version != 7)) return false;

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
                (saveData.IsSleeping ? 1 : 0) + (saveData.IsWorking ? 1 : 0) + (saveData.IsStudying ? 1 : 0) + (saveData.IsPlaying ? 1 : 0) + (saveData.IsSpendingFamilyTime ? 1 : 0) > 1 ||
                saveData.PlayMinutesAccumulator < 0 || saveData.PlayMinutesAccumulator >= 60 ||
                saveData.FamilyTimeMinutesAccumulator < 0 || saveData.FamilyTimeMinutesAccumulator >= 60 ||
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

            // Validate Traits if version 4+ (V4/V5 saves persist traits; V2/V3 default to 50)
            double traitConfidence = 50.0;
            double traitCuriosity = 50.0;
            double traitPatience = 50.0;
            double traitAmbition = 50.0;
            double traitEmpathy = 50.0;
            if (saveData.Version >= 4)
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

            // Validate Family if version 6+ (V5 and earlier have no family data; defaults apply)
            Guid motherId = Guid.Empty;
            string motherName = "Mother";
            long motherBirthDay = -(28L * 365);
            Guid fatherId = Guid.Empty;
            string fatherName = "Father";
            long fatherBirthDay = -(30L * 365);
            double motherCloseness = 50.0;
            double fatherCloseness = 50.0;
            bool hasFamilyData = saveData.Version >= 6;
            if (saveData.Version >= 6)
            {
                motherId = saveData.MotherId;
                motherName = saveData.MotherName;
                motherBirthDay = saveData.MotherBirthDay;
                fatherId = saveData.FatherId;
                fatherName = saveData.FatherName;
                fatherBirthDay = saveData.FatherBirthDay;
                motherCloseness = saveData.MotherCloseness;
                fatherCloseness = saveData.FatherCloseness;

                // Person identity validation
                if (motherId == Guid.Empty || fatherId == Guid.Empty || motherId == fatherId)
                    return false;
                if (string.IsNullOrWhiteSpace(motherName) || string.IsNullOrWhiteSpace(fatherName))
                    return false;
                if (saveData.MotherBirthDay > saveData.Day || saveData.FatherBirthDay > saveData.Day)
                    return false;

                // Relationship validation: finite range + exact cross-reference
                if (!IsValidCloseness(saveData.MotherCloseness) || !IsValidCloseness(saveData.FatherCloseness))
                    return false;
                if (saveData.MotherRelationshipPersonId != motherId || saveData.FatherRelationshipPersonId != fatherId)
                    return false;
            }

            // Validate event data if version 7+ (V6 and earlier have none; defaults apply)
            long totalPlayHours = 0;
            string? pendingEventId = null;
            long pendingTriggeredDay = 0;
            List<EventHistorySaveData> eventHistory = new();
            bool hasEventData = saveData.Version >= 7;
            if (saveData.Version >= 7)
            {
                totalPlayHours = saveData.TotalPlayHours;
                if (totalPlayHours < 0) return false;

                // Pending event: must be a known event with a valid trigger day.
                pendingEventId = saveData.CurrentEventId;
                if (pendingEventId != null)
                {
                    if (!LifeEventCatalog.IsKnownEvent(pendingEventId)) return false;
                    pendingTriggeredDay = saveData.CurrentEventTriggeredDay;
                    if (pendingTriggeredDay < 0 || pendingTriggeredDay > saveData.Day) return false;
                }

                // History: known events, valid paired choices, valid day ordering,
                // no duplicate one-shot events, no pending/history conflict.
                eventHistory = saveData.EventHistory ?? new List<EventHistorySaveData>();
                var seen = new HashSet<string>();
                foreach (var entry in eventHistory)
                {
                    if (entry == null || !LifeEventCatalog.IsKnownEvent(entry.EventId)) return false;
                    if (!LifeEventCatalog.IsKnownChoice(entry.EventId, entry.ChoiceId)) return false;
                    if (entry.TriggeredDay < 0) return false;
                    if (entry.ResolvedDay < entry.TriggeredDay) return false;
                    if (entry.ResolvedDay > saveData.Day) return false;
                    if (!seen.Add(entry.EventId)) return false; // one-shot duplicates invalid
                }
                if (pendingEventId != null && seen.Contains(pendingEventId)) return false;
            }

            // Transactional Load: Create clones for validation
            var tempClock = new GameClock();
            tempClock.Restore(saveData.Day, saveData.Hour, saveData.Minute);
            var tempPlayer = new PlayerState(tempClock);
            tempPlayer.Restore(saveData.Money, saveData.Energy, saveData.Hunger, saveData.Thirst, saveData.StudyXP,
                saveData.IsSleeping, saveData.IsWorking, saveData.IsStudying, saveData.IsPlaying, saveData.IsSpendingFamilyTime,
                saveData.AwakeMinutesAccumulator, saveData.SleepingMinutesAccumulator,
                saveData.HungerMinutesAccumulator, saveData.ThirstMinutesAccumulator,
                saveData.WorkMinutesAccumulator, saveData.StudyMinutesAccumulator,
                saveData.PlayMinutesAccumulator, saveData.FamilyTimeMinutesAccumulator);
            tempPlayer.Attributes.Restore(attrIntelligence, attrFitness, attrSocial, attrDiscipline, attrCreativity);
            tempPlayer.Skills.Academics.Restore(saveData.AcademicsExperience);
            tempPlayer.Education.Restore(eduStatus, eduGrade, eduProgress, eduStartDay);
            tempPlayer.Traits.Restore(traitConfidence, traitCuriosity, traitPatience, traitAmbition, traitEmpathy);

            // Restore event state (replaces fresh defaults for V7)
            if (hasEventData)
            {
                tempPlayer.RestoreTotalPlayHours(totalPlayHours);
                if (eventHistory.Count > 0)
                {
                    var historyEntries = new List<EventHistoryEntry>();
                    foreach (var entry in eventHistory)
                    {
                        historyEntries.Add(new EventHistoryEntry(entry.EventId, entry.ChoiceId, entry.TriggeredDay, entry.ResolvedDay));
                    }
                    // Single all-or-nothing restore preserves order and rejects duplicates.
                    tempPlayer.Events.RestoreHistory(historyEntries);
                }
                if (pendingEventId != null)
                {
                    tempPlayer.Events.RestorePending(pendingEventId, pendingTriggeredDay);
                }
            }

            // Restore family + relationships (replaces temp constructor-generated IDs for V6)
            if (hasFamilyData)
            {
                tempPlayer.Family.Restore(
                    new Person(motherId, motherName, motherBirthDay, PersonRole.Mother),
                    new Person(fatherId, fatherName, fatherBirthDay, PersonRole.Father));
                tempPlayer.Relationships.Restore(
                    new Relationship(motherId, motherCloseness),
                    new Relationship(fatherId, fatherCloseness));
            }

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

            // Offline progression remains bulk/O(1): evaluate event eligibility ONCE
            // against the FINAL state. TriggeredDay becomes the final current day.
            tempPlayer.Events.EvaluateTriggers(tempClock.Day);

            // Commit to live objects
            clock.Restore(tempClock.Day, tempClock.Hour, tempClock.Minute);
            player.Restore(tempPlayer.Money, tempPlayer.Energy, tempPlayer.Hunger, tempPlayer.Thirst, tempPlayer.StudyXP,
                tempPlayer.IsSleeping, tempPlayer.IsWorking, tempPlayer.IsStudying, tempPlayer.IsPlaying, tempPlayer.IsSpendingFamilyTime,
                tempPlayer.GetAwakeMinutesAccumulator(), tempPlayer.GetSleepingMinutesAccumulator(),
                tempPlayer.GetHungerMinutesAccumulator(), tempPlayer.GetThirstMinutesAccumulator(),
                tempPlayer.GetWorkMinutesAccumulator(), tempPlayer.GetStudyMinutesAccumulator(),
                tempPlayer.GetPlayMinutesAccumulator(), tempPlayer.GetFamilyTimeMinutesAccumulator());
            player.Attributes.Restore(tempPlayer.Attributes.Intelligence, tempPlayer.Attributes.Fitness, tempPlayer.Attributes.Social, tempPlayer.Attributes.Discipline, tempPlayer.Attributes.Creativity);
            player.Skills.Academics.Restore(tempPlayer.Skills.Academics.Experience);
            player.Education.Restore(tempPlayer.Education.Status, tempPlayer.Education.PrimaryGrade, tempPlayer.Education.EducationProgress, tempPlayer.Education.SchoolYearStartDay);
            player.Traits.Restore(tempPlayer.Traits.Confidence, tempPlayer.Traits.Curiosity, tempPlayer.Traits.Patience, tempPlayer.Traits.Ambition, tempPlayer.Traits.Empathy);
            player.Family.Restore(tempPlayer.Family.Mother, tempPlayer.Family.Father);
            player.Relationships.Restore(tempPlayer.Relationships.MotherRelationship, tempPlayer.Relationships.FatherRelationship);
            player.RestoreTotalPlayHours(tempPlayer.TotalPlayHours);
            player.Events.ClearPending();
            player.Events.RestoreHistory(tempPlayer.Events.History);
            if (tempPlayer.Events.CurrentEvent != null)
            {
                player.Events.RestorePending(tempPlayer.Events.CurrentEvent.EventId, tempPlayer.Events.CurrentEvent.TriggeredDay);
            }

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

    private static bool IsValidCloseness(double value)
    {
        return !double.IsNaN(value) && !double.IsInfinity(value) && value >= 0.0 && value <= 100.0;
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