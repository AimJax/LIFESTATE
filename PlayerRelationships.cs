namespace Lifestate;

public sealed class PlayerRelationships
{
    public Relationship MotherRelationship { get; private set; }
    public Relationship FatherRelationship { get; private set; }

    public PlayerRelationships(Guid motherPersonId, Guid fatherPersonId)
    {
        MotherRelationship = new Relationship(motherPersonId);
        FatherRelationship = new Relationship(fatherPersonId);
    }

    internal void Restore(Relationship mother, Relationship father)
    {
        if (mother == null || father == null) return;
        if (mother.PersonId == Guid.Empty || father.PersonId == Guid.Empty) return;
        if (mother.PersonId == father.PersonId) return;

        MotherRelationship = mother;
        FatherRelationship = father;
    }
}
