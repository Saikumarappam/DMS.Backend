using DMS.Application.Interfaces;

using DMS.Infrastructure.Repositories;



namespace DMS.Infrastructure.Services;



public class ApiLogService : IApiLogService

{

    private readonly ApiLogRepository _repository;



    public ApiLogService(ApiLogRepository repository) => _repository = repository;



    public void Log(

        string eventSource,

        string eventProcedure,

        string? param,

        string eventDescription,

        bool isError,

        string? uniqueId)

    {

        _ = LogAsync(eventSource, eventProcedure, param, eventDescription, isError, uniqueId);

    }



    public Task LogAsync(

        string eventSource,

        string eventProcedure,

        string? param,

        string eventDescription,

        bool isError,

        string? uniqueId) =>

        _repository.InsertAsync(eventSource, eventProcedure, param, eventDescription, isError, uniqueId);

}

