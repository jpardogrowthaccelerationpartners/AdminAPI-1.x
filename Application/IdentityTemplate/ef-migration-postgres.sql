﻿-- SPDX-License-Identifier: Apache-2.0
-- Licensed to the Ed-Fi Alliance under one or more agreements.
-- The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
-- See the LICENSE and NOTICES files in the project root for more information.

CREATE TABLE adminapp.Users (
    Id TEXT NOT NULL,
    UserName CHARACTER VARYING(256) NULL,
    NormalizedUserName CHARACTER VARYING(256) NULL,
    Email CHARACTER VARYING(256) NULL,
    NormalizedEmail CHARACTER VARYING(256) NULL,
    EmailConfirmed BOOLEAN NOT NULL,
    PasswordHash TEXT NULL,
    SecurityStamp TEXT NULL,
    ConcurrencyStamp TEXT NULL,
    PhoneNumber TEXT NULL,
    PhoneNumberConfirmed BOOLEAN NOT NULL,
    TwoFactorEnabled BOOLEAN NOT NULL,
    LockoutEnd TIMESTAMP WITH TIME ZONE NULL,
    LockoutEnabled BOOLEAN NOT NULL,
    AccessFailedCount INTEGER NOT NULL,
    CONSTRAINT PK_Users PRIMARY KEY (Id)
);

CREATE TABLE adminapp.Roles (
    Id TEXT NOT NULL,
    Name CHARACTER VARYING(256) NULL,
    NormalizedName CHARACTER VARYING(256) NULL,
    ConcurrencyStamp TEXT NULL,
    CONSTRAINT PK_Roles PRIMARY KEY (Id)
);

CREATE TABLE adminapp.UserClaims (
    Id INTEGER NOT NULL GENERATED BY DEFAULT AS IDENTITY,
    UserId TEXT NOT NULL,
    ClaimType TEXT NULL,
    ClaimValue TEXT NULL,
    CONSTRAINT PK_UserClaims PRIMARY KEY (Id),
    CONSTRAINT FK_UserClaims_Users_UserId FOREIGN KEY (UserId) REFERENCES adminapp.Users (Id) ON DELETE CASCADE
);

CREATE TABLE adminapp.RoleClaims (
    Id INTEGER NOT NULL GENERATED BY DEFAULT AS IDENTITY,
    RoleId TEXT NOT NULL,
    ClaimType TEXT NULL,
    ClaimValue TEXT NULL,
    CONSTRAINT PK_RoleClaims PRIMARY KEY (Id),
    CONSTRAINT FK_RoleClaims_Roles_RoleId FOREIGN KEY (RoleId) REFERENCES adminapp.Roles (Id) ON DELETE CASCADE
);

CREATE TABLE adminapp.UserLogins (
    LoginProvider CHARACTER VARYING(128) NOT NULL,
    ProviderKey CHARACTER VARYING(128) NOT NULL,
    ProviderDisplayName TEXT NULL,
    UserId TEXT NOT NULL,
    CONSTRAINT PK_UserLogins PRIMARY KEY (LoginProvider, ProviderKey),
    CONSTRAINT FK_UserLogins_Users_UserId FOREIGN KEY (UserId) REFERENCES adminapp.Users (Id) ON DELETE CASCADE
);

CREATE TABLE adminapp.UserRoles (
    UserId TEXT NOT NULL,
    RoleId TEXT NOT NULL,
    CONSTRAINT PK_UserRoles PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_UserRoles_Roles_RoleId FOREIGN KEY (RoleId) REFERENCES adminapp.Roles (Id) ON DELETE CASCADE,
    CONSTRAINT FK_UserRoles_Users_UserId FOREIGN KEY (UserId) REFERENCES adminapp.Users (Id) ON DELETE CASCADE
);

CREATE TABLE adminapp.UserTokens (
    UserId TEXT NOT NULL,
    LoginProvider CHARACTER VARYING(128) NOT NULL,
    Name CHARACTER VARYING(128) NOT NULL,
    Value TEXT NULL,
    CONSTRAINT PK_UserTokens PRIMARY KEY (UserId, LoginProvider, Name),
    CONSTRAINT FK_UserTokens_Users_UserId FOREIGN KEY (UserId) REFERENCES adminapp.Users (Id) ON DELETE CASCADE
);

CREATE INDEX IX_RoleClaims_RoleId ON adminapp.RoleClaims (RoleId);
CREATE UNIQUE INDEX RoleNameIndex ON adminapp.Roles (NormalizedName);
CREATE INDEX IX_UserClaims_UserId ON adminapp.UserClaims (UserId);
CREATE INDEX IX_UserLogins_UserId ON adminapp.UserLogins (UserId);
CREATE INDEX IX_UserRoles_RoleId ON adminapp.UserRoles (RoleId);
CREATE INDEX EmailIndex ON adminapp.Users (NormalizedEmail);
CREATE UNIQUE INDEX UserNameIndex ON adminapp.Users (NormalizedUserName);
