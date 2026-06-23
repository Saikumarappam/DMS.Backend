namespace DMS.Application.Interfaces;



public interface IApiLogService

{

    void Log(

        string eventSource,

        string eventProcedure,

        string? param,

        string eventDescription,

        bool isError,

        string? uniqueId);



    Task LogAsync(

        string eventSource,

        string eventProcedure,

        string? param,

        string eventDescription,

        bool isError,

        string? uniqueId);

}

