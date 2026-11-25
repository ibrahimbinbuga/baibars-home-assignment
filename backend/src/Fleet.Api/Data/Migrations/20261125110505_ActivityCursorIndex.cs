using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Fleet.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class ActivityCursorIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ActivityEvents_VehicleId_OccurredAt",
                table: "ActivityEvents");

            migrationBuilder.CreateIndex(
                name: "IX_ActivityEvents_VehicleId_OccurredAt_Id",
                table: "ActivityEvents",
                columns: new[] { "VehicleId", "OccurredAt", "Id" },
                descending: new[] { false, true, true });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ActivityEvents_VehicleId_OccurredAt_Id",
                table: "ActivityEvents");

            migrationBuilder.CreateIndex(
                name: "IX_ActivityEvents_VehicleId_OccurredAt",
                table: "ActivityEvents",
                columns: new[] { "VehicleId", "OccurredAt" },
                descending: new[] { false, true });
        }
    }
}
