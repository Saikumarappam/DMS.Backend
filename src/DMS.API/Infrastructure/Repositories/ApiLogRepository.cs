using DMS.API.Helpers;

using DMS.Application.Interfaces;



namespace DMS.Infrastructure.Repositories;



public class ApiLogRepository

{

    private readonly CommonFunctions _commonFunctions;



    public ApiLogRepository(CommonFunctions commonFunctions) => _commonFunctions = commonFunctions;



    public Task InsertAsync(

        string eventSource,

        string eventProcedure,

        string? param,

        string eventDescription,

        bool isError,

        string? uniqueId) =>

        _commonFunctions.LogEventAsync(

            eventSource,

            eventProcedure,

            param ?? "",

            eventDescription,

            isError ? 1 : 0,

            uniqueId ?? "");

}

