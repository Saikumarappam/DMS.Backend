using DMS.Application.Interfaces;

namespace DMS.Infrastructure.Services;

public class BcryptPasswordHasher : IPasswordHasher
{
    public string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password, 11);
    public bool Verify(string password, string hash)
    {
        bool status = BCrypt.Net.BCrypt.Verify(password, hash);
        return status;

    }
}
