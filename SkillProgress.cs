namespace Lifestate;

public sealed class SkillProgress
{
    public const long MaxExperience = 10000;
    
    public long Experience { get; private set; } = 0;

    public int Level => (int)(Experience / 100);

    internal void AddExperience(long amount)
    {
        if (amount <= 0) return;

        if (amount >= MaxExperience - Experience)
        {
            Experience = MaxExperience;
        }
        else
        {
            Experience += amount;
        }
    }

    internal void Restore(long experience)
    {
        if (experience >= 0 && experience <= MaxExperience)
        {
            Experience = experience;
        }
    }

    internal void SetMax()
    {
        Experience = MaxExperience;
    }
}
