using System.Text.Json;
using System.IO;

namespace Lifestate;

public class SaveData
{
    public int Version { get; set; } = 7;
    public int Day { get; set; }
    public int Hour { get; set; }
    public int Minute { get; set; }
    public int Money { get; set; }
    public int Energy { get; set; }
    public int Hunger { get; set; }
    public int Thirst { get; set; }
    public int StudyXP { get; set; }
    public bool IsSleeping { get; set; }
    public bool IsWorking { get; set; }
    public bool IsStudying { get; set; }
    public bool IsPlaying { get; set; }
    public bool IsSpendingFamilyTime { get; set; }
    public int WorkMinutesAccumulator { get; set; }
    public int StudyMinutesAccumulator { get; set; }
    public int AwakeMinutesAccumulator { get; set; }
    public int SleepingMinutesAccumulator { get; set; }
    public int HungerMinutesAccumulator { get; set; }
    public int ThirstMinutesAccumulator { get; set; }
    public int PlayMinutesAccumulator { get; set; }
    public int FamilyTimeMinutesAccumulator { get; set; }
    public long AcademicsExperience { get; set; }
    public int EducationStatus { get; set; }
    public int PrimaryGrade { get; set; }
    public int EducationProgress { get; set; }
    public long SchoolYearStartDay { get; set; }
    public long TotalPlayHours { get; set; }
    public string? CurrentEventId { get; set; }
    public long CurrentEventTriggeredDay { get; set; }
    public List<EventHistorySaveData> EventHistory { get; set; } = new();
    public Guid MotherId { get; set; }
    public string MotherName { get; set; } = "";
    public long MotherBirthDay { get; set; }
    public Guid FatherId { get; set; }
    public string FatherName { get; set; } = "";
    public long FatherBirthDay { get; set; }
    public Guid MotherRelationshipPersonId { get; set; }
    public double MotherCloseness { get; set; }
    public Guid FatherRelationshipPersonId { get; set; }
    public double FatherCloseness { get; set; }
    public double Confidence { get; set; }
    public double Curiosity { get; set; }
    public double Patience { get; set; }
    public double Ambition { get; set; }
    public double Empathy { get; set; }
    public double? Intelligence { get; set; }
    public double? Fitness { get; set; }
    public double? Social { get; set; }
    public double? Discipline { get; set; }
    public double? Creativity { get; set; }
    public DateTimeOffset SavedAtUtc { get; set; }
}

public class EventHistorySaveData
{
    public string EventId { get; set; } = "";
    public string ChoiceId { get; set; } = "";
    public long TriggeredDay { get; set; }
    public long ResolvedDay { get; set; }
}