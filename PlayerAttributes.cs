namespace Lifestate;

public sealed class PlayerAttributes
{
    public double Intelligence { get; private set; } = 10.0;
    public double Fitness { get; private set; } = 10.0;
    public double Social { get; private set; } = 10.0;
    public double Discipline { get; private set; } = 10.0;
    public double Creativity { get; private set; } = 10.0;

    public void AddIntelligence(double amount)
    {
        if (IsValidInput(amount)) Intelligence = Clamp(Intelligence + amount);
    }
    public void AddFitness(double amount)
    {
        if (IsValidInput(amount)) Fitness = Clamp(Fitness + amount);
    }
    public void AddSocial(double amount)
    {
        if (IsValidInput(amount)) Social = Clamp(Social + amount);
    }
    public void AddDiscipline(double amount)
    {
        if (IsValidInput(amount)) Discipline = Clamp(Discipline + amount);
    }
    public void AddCreativity(double amount)
    {
        if (IsValidInput(amount)) Creativity = Clamp(Creativity + amount);
    }

    public void SetAllMax()
    {
        Intelligence = 100.0;
        Fitness = 100.0;
        Social = 100.0;
        Discipline = 100.0;
        Creativity = 100.0;
    }

    private static bool IsValidInput(double amount)
    {
        return !double.IsNaN(amount) && !double.IsInfinity(amount);
    }

    private static double Clamp(double value)
    {
        return Math.Clamp(value, 0.0, 100.0);
    }

    internal void Restore(double intelligence, double fitness, double social, double discipline, double creativity)
    {
        Intelligence = Clamp(intelligence);
        Fitness = Clamp(fitness);
        Social = Clamp(social);
        Discipline = Clamp(discipline);
        Creativity = Clamp(creativity);
    }
}
