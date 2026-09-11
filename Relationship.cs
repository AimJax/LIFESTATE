namespace Lifestate;

public sealed class Relationship
{
    public Guid PersonId { get; }
    public double Closeness { get; private set; }

    public Relationship(Guid personId, double closeness = 50.0)
    {
        PersonId = personId;
        Closeness = IsValidValue(closeness) ? Clamp(closeness) : 50.0;
    }

    internal void AddCloseness(double amount)
    {
        if (IsValidValue(amount)) Closeness = Clamp(Closeness + amount);
    }

    internal void RestoreCloseness(double value)
    {
        if (IsValidValue(value)) Closeness = Clamp(value);
    }

    private static bool IsValidValue(double value)
    {
        return !double.IsNaN(value) && !double.IsInfinity(value);
    }

    private static double Clamp(double value)
    {
        return Math.Clamp(value, 0.0, 100.0);
    }
}
