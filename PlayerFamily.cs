namespace Lifestate;

public sealed class PlayerFamily
{
    public Person Mother { get; private set; }
    public Person Father { get; private set; }

    public PlayerFamily()
    {
        // Starting parents exist immediately at player birth.
        // Ages at Day 0: Mother 28, Father 30 => BirthDay = -(age * 365).
        Mother = new Person(Guid.NewGuid(), "Mother", -(28L * 365), PersonRole.Mother);
        Father = new Person(Guid.NewGuid(), "Father", -(30L * 365), PersonRole.Father);
    }

    internal void Restore(Person mother, Person father)
    {
        if (mother == null || father == null) return;
        if (mother.Id == Guid.Empty || father.Id == Guid.Empty) return;
        if (mother.Id == father.Id) return;
        if (mother.Role != PersonRole.Mother || father.Role != PersonRole.Father) return;

        Mother = mother;
        Father = father;
    }
}
