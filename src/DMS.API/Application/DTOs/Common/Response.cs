using System.Collections.Specialized;

namespace DMS.Application.DTOs.Common;

public class Response
{
    public bool status { get; set; }
    public string statuscode { get; set; } = "";
    public string message { get; set; } = "";
    public string token { get; set; } = "";
    public ListDictionary? data { get; set; }
    public string jsonstring { get; set; } = "";
}
