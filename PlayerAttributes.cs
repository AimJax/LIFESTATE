namespace Lifestate;

public sealed class PlayerAttributes
{
    public double Intelligence { get; private set; } = 10.0;
    public double Fitness { get; private set; } = 10.0;
    public double Social { get; private set; } = 10.0;
    public double Discipline { get; private set; } = 10.0;
    public double Creativity { get; private set; } = 10.0;

    public void AddIntelligence(double amount) => Intelligence = Clamp(Intelligence + amount);
    public void AddFitness(double amount) => Fitness = Clamp(Fitness + amount);
    public void AddSocial(double amount) => Social = Clamp(Social + amount);
    public void AddDiscipline(double amount) => Discipline = Clamp(Discipline + amount);
    public void AddCreativity(double amount) => Creativity = Clamp(Creativity + amount);

    public void SetAllMax()
    {
        Intelligence = 100.0;
        Fitness = 100.0;
        Social = 100.0;
        Discipline = 100.0;
        Creativity = 100.0;
    }

    private static double Clamp(double value)
    {
        if (double.IsNaN(value) || double.IsInfinity(value)) return 0.0;
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