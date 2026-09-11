namespace Lifestate;

public enum PersonRole
{
    Mother,
    Father
}

public sealed class Person
{
    public Guid Id { get; }
    public string Name { get; }
    public long BirthDay { get; }
    public PersonRole Role { get; }

    public Person(Guid id, string name, long birthDay, PersonRole role)
    {
        Id = id;
        Name = name;
        BirthDay = birthDay;
        Role = role;
    }

    public int GetAge(long currentDay)
    {
        long age = (currentDay - BirthDay) / 365;
        if (age < 0) age = 0;
        return (int)age;
    }

    public int GetAge(GameClock clock) => GetAge(clock.Day);
}
