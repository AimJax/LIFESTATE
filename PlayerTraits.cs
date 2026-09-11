namespace Lifestate;

public sealed class PlayerTraits
{
    public double Confidence { get; private set; } = 50.0;
    public double Curiosity { get; private set; } = 50.0;
    public double Patience { get; private set; } = 50.0;
    public double Ambition { get; private set; } = 50.0;
    public double Empathy { get; private set; } = 50.0;

    public void AddConfidence(double amount)
    {
        if (IsValidInput(amount)) Confidence = Clamp(Confidence + amount);
    }
    public void AddCuriosity(double amount)
    {
        if (IsValidInput(amount)) Curiosity = Clamp(Curiosity + amount);
    }
    public void AddPatience(double amount)
    {
        if (IsValidInput(amount)) Patience = Clamp(Patience + amount);
    }
    public void AddAmbition(double amount)
    {
        if (IsValidInput(amount)) Ambition = Clamp(Ambition + amount);
    }
    public void AddEmpathy(double amount)
    {
        if (IsValidInput(amount)) Empathy = Clamp(Empathy + amount);
    }

    public void SetAllMax()
    {
        Confidence = 100.0;
        Curiosity = 100.0;
        Patience = 100.0;
        Ambition = 100.0;
        Empathy = 100.0;
    }

    private static bool IsValidInput(double amount)
    {
        return !double.IsNaN(amount) && !double.IsInfinity(amount);
    }

    private static double Clamp(double value)
    {
        return Math.Clamp(value, 0.0, 100.0);
    }

    internal void Restore(double confidence, double curiosity, double patience, double ambition, double empathy)
    {
        if (IsValidInput(confidence)) Confidence = Clamp(confidence);
        if (IsValidInput(curiosity)) Curiosity = Clamp(curiosity);
        if (IsValidInput(patience)) Patience = Clamp(patience);
        if (IsValidInput(ambition)) Ambition = Clamp(ambition);
        if (IsValidInput(empathy)) Empathy = Clamp(empathy);
    }
}
