namespace Lifestate;

public enum EducationStatus
{
    NotEnrolled,
    PrimarySchool,
    CompletedPrimary
}

public sealed class EducationState
{
    public EducationStatus Status { get; private set; } = EducationStatus.NotEnrolled;
    public int PrimaryGrade { get; private set; } = 0;
    public int EducationProgress { get; private set; } = 0;
    public long SchoolYearStartDay { get; private set; } = 0;

    internal bool TryEnroll(int currentDay)
    {
        if (Status != EducationStatus.NotEnrolled) return false;

        Status = EducationStatus.PrimarySchool;
        PrimaryGrade = 1;
        EducationProgress = 0;
        SchoolYearStartDay = currentDay;
        return true;
    }

    internal void AddProgress(int hours)
    {
        if (Status != EducationStatus.PrimarySchool || hours <= 0) return;
        EducationProgress = Math.Min(100, EducationProgress + hours);
    }

    internal void EvaluateProgression(int currentDay)
    {
        if (Status != EducationStatus.PrimarySchool) return;

        // Bounded loop: at most 6 grades can be completed
        for (int i = 0; i < 6; i++)
        {
            if (Status != EducationStatus.PrimarySchool) break;

            bool calendarEligible = (currentDay - SchoolYearStartDay) >= 365;
            bool progressEligible = EducationProgress >= 100;

            if (calendarEligible && progressEligible)
            {
                if (PrimaryGrade < 6)
                {
                    PrimaryGrade++;
                    EducationProgress = 0;
                    SchoolYearStartDay = currentDay;
                }
                else
                {
                    Status = EducationStatus.CompletedPrimary;
                    PrimaryGrade = 6;
                    EducationProgress = 100;
                    break;
                }
            }
            else
            {
                break;
            }
        }
    }

    internal void Restore(EducationStatus status, int grade, int progress, long startDay)
    {
        // Defense-in-depth invariant protection
        if (status == EducationStatus.NotEnrolled)
        {
            if (grade != 0 || progress != 0 || startDay != 0) return;
        }
        else if (status == EducationStatus.PrimarySchool)
        {
            if (grade < 1 || grade > 6 || progress < 0 || progress > 100 || startDay < 0) return;
        }
        else if (status == EducationStatus.CompletedPrimary)
        {
            if (grade != 6 || progress != 100 || startDay < 0) return;
        }
        else return;

        Status = status;
        PrimaryGrade = grade;
        EducationProgress = progress;
        SchoolYearStartDay = startDay;
    }
}