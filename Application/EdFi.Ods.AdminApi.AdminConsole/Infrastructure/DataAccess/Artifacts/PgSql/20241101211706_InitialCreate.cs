﻿using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace EdFi.Ods.AdminApi.AdminConsole.Infrastructure.DataAccess.Artifacts.PgSql
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "adminconsole");

            migrationBuilder.CreateTable(
                name: "HealthChecks",
                schema: "adminconsole",
                columns: table => new
                {
                    DocId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    InstanceId = table.Column<int>(type: "integer", nullable: false),
                    EdOrgId = table.Column<int>(type: "integer", nullable: false),
                    TenantId = table.Column<int>(type: "integer", nullable: false),
                    Document = table.Column<string>(type: "jsonb", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HealthChecks", x => x.DocId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_HealthChecks_EdOrgId",
                schema: "adminconsole",
                table: "HealthChecks",
                column: "EdOrgId");

            migrationBuilder.CreateIndex(
                name: "IX_HealthChecks_InstanceId",
                schema: "adminconsole",
                table: "HealthChecks",
                column: "InstanceId");

            migrationBuilder.CreateIndex(
                name: "IX_HealthChecks_TenantId",
                schema: "adminconsole",
                table: "HealthChecks",
                column: "TenantId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "HealthChecks",
                schema: "adminconsole");
        }
    }
}
