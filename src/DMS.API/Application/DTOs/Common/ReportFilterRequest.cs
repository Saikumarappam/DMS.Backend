namespace DMS.Application.DTOs.Common;

public class ReportFilterRequest
{
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
    public int? Year { get; set; }
}
