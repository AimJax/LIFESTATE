using System.Text.Json;
using System.IO;

namespace Lifestate;

public class SaveData
{
    public int Version { get; set; } = 2;
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
    public int WorkMinutesAccumulator { get; set; }
    public int StudyMinutesAccumulator { get; set; }
    public double? Intelligence { get; set; }
    public double? Fitness { get; set; }
    public double? Social { get; set; }
    public double? Discipline { get; set; }
    public double? Creativity { get; set; }
    public DateTimeOffset SavedAtUtc { get; set; }
}