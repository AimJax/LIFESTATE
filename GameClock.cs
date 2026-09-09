namespace Lifestate;

public class GameClock
{
    public const int MinutesPerRealSecond = 4; // 1 real second = 4 in-game minutes

    public int Day { get; private set; }
    public int Year => Day / 365;
    public int DayOfYear => Day % 365;
    public int Hour { get; private set; }
    public int Minute { get; private set; }

    public GameClock()
    {
        Day = 0;
        Hour = 0;
        Minute = 0;
    }

    public void AdvanceGameMinutes(long minutes)
    {
        if (minutes < 0) return;

        long totalMinutes = Minute + minutes;
        int newMinute = (int)(totalMinutes % 60);
        long hoursToAdd = totalMinutes / 60;
        
        long totalHours = Hour + hoursToAdd;
        int newHour = (int)(totalHours % 24);
        long daysToAdd = totalHours / 24;
        
        long newDay = (long)Day + daysToAdd;
        if (newDay > int.MaxValue)
        {
            throw new System.OverflowException("GameClock Day overflow");
        }
        
        Day = (int)newDay;
        Hour = (int)newHour;
        Minute = (int)newMinute;
    }

    public void AdvanceSeconds(int realSecondsElapsed)
    {
        AdvanceGameMinutes((long)realSecondsElapsed * MinutesPerRealSecond);
    }

    public override string ToString() => $"Day {Day}, {Hour:00}:{Minute:00}";
    internal void Restore(int day, int hour, int minute)
    {
        Day = day;
        Hour = hour;
        Minute = minute;
    }

}