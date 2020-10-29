// SPDX-License-Identifier: Apache-2.0
// Licensed to the Ed-Fi Alliance under one or more agreements.
// The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
// See the LICENSE and NOTICES files in the project root for more information.

using System;
using System.Linq;
#if NET48
using System.Web.Mvc;
using Castle.MicroKernel.Registration;
using Castle.MicroKernel.SubSystems.Configuration;
using Castle.Windsor;
#else
using EdFi.Ods.Common.Extensions;
#endif
using EdFi.Admin.DataAccess.Contexts;
using EdFi.Admin.LearningStandards.Core.Configuration;
using EdFi.Admin.LearningStandards.Core.Services;
using EdFi.Admin.LearningStandards.Core.Services.Interfaces;
using EdFi.Ods.AdminApp.Management;
using EdFi.Ods.AdminApp.Management.Api;
using EdFi.Ods.AdminApp.Management.Configuration.Application;
using EdFi.Ods.AdminApp.Management.Database;
using EdFi.Ods.AdminApp.Management.Helpers;
using EdFi.Ods.AdminApp.Web.Hubs;
using EdFi.Ods.AdminApp.Web.Infrastructure;
using EdFi.Ods.AdminApp.Web.Infrastructure.IO;
using EdFi.Ods.AdminApp.Web.Infrastructure.Jobs;
using EdFi.Ods.Common.Configuration;
using EdFi.Ods.Common.Security;
using EdFi.Security.DataAccess.Contexts;
using FluentValidation;
using Hangfire;
using log4net;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Clients.ActiveDirectory;


namespace EdFi.Ods.AdminApp.Web._Installers
{
    public abstract class CommonConfigurationInstaller
#if NET48
        : IWindsorInstaller
#endif
    {
        private static readonly ILog Logger = LogManager.GetLogger(typeof(CommonConfigurationInstaller));

#if NET48
        public void Install(IWindsorContainer services, IConfigurationStore store)
#else
        public void Install(IServiceCollection services)
#endif
        {
            services.AddTransient<IFileUploadHandler, LocalFileSystemFileUploadHandler>();

#if NET48
            services.AddSingleton(AutoMapperBootstrapper.CreateMapper());

            services.AddSingleton<IApiConfigurationProvider, ApiConfigurationProvider>();
            services.AddSingleton<IConfigValueProvider, AppConfigValueProvider>();
            services.AddSingleton<IDatabaseEngineProvider, DatabaseEngineProvider>();
            services.AddSingleton<IConfigConnectionStringsProvider, AppConfigConnectionStringsProvider>();

            services.AddSingleton<ISecurityContextFactory, SecurityContextFactory>();
            services.AddSingleton<IUsersContextFactory, UsersContextFactory>();
            services.AddScoped(x => x.GetService<ISecurityContextFactory>().CreateContext());
            services.AddScoped(x => x.GetService<IUsersContextFactory>().CreateContext());
#else
            services.AddScoped<ISecurityContext>(x =>
            {
                var appSettings = x.GetService<IOptions<AppSettings>>();
                var connectionStrings = x.GetService<IOptions<ConnectionStrings>>();

                if (appSettings.Value.DatabaseEngine.EqualsIgnoreCase("SqlServer"))
                    return new SqlServerSecurityContext(connectionStrings.Value.Security);

                return new PostgresSecurityContext(connectionStrings.Value.Security);
            });

            services.AddScoped<IUsersContext>(x =>
            {
                var appSettings = x.GetService<IOptions<AppSettings>>();
                var connectionStrings = x.GetService<IOptions<ConnectionStrings>>();

                if (appSettings.Value.DatabaseEngine.EqualsIgnoreCase("SqlServer"))
                    return new SqlServerUsersContext(connectionStrings.Value.Admin);

                return new PostgresUsersContext(connectionStrings.Value.Admin);
            });
#endif

            services.AddSingleton(TokenCache.DefaultShared);


#if NET48
            //For the .NET Core registration of this type, see Startup.cs.
            services.AddScoped<AdminAppDbContext>();

            //For the .NET Core registration of this type, see Startup.cs.
            //Note that in NET48 runs, this scoped instance is distinct from
            //the scoped instance available via the OWIN IoC container.
            services.AddScoped<AdminAppIdentityDbContext>();
#endif

            services.AddScoped<AdminAppUserContext>();

            services.AddTransient<ICloudOdsAdminAppSettingsApiModeProvider, CloudOdsAdminAppSettingsApiModeProvider>();

            services.AddSingleton<ICachedItems, CachedItems>();

            services.AddTransient<IOdsApiConnectionInformationProvider, CloudOdsApiConnectionInformationProvider>();

#if NET48
            services.AddSingleton<IOptions<AppSettings>>(
                new Net48Options<AppSettings>(ConfigurationHelper.GetAppSettings()));

            services.AddSingleton<IOptions<ConnectionStrings>>(
                new Net48Options<ConnectionStrings>(ConfigurationHelper.GetConnectionStrings()));

            services.Register(
                Classes.FromThisAssembly()
                    .BasedOn<IController>()
                    .LifestyleTransient());
#endif

            services.AddTransient<ProductionSetupHub>();
            services.AddTransient<BulkUploadHub>();
            services.AddTransient<ProductionLearningStandardsHub>();
            services.AddTransient<BulkImportService>();
            services.AddTransient<IBackgroundJobClient, BackgroundJobClient>();

            services.AddSingleton<IProductionSetupJob, ProductionSetupJob>();
            services.AddSingleton(x => (WorkflowJob<int, ProductionSetupHub>)x.GetService<IProductionSetupJob>());//Resolve previously queued job.

            services.AddSingleton<IBulkUploadJob, BulkUploadJob>();
            services.AddSingleton(x => (WorkflowJob<BulkUploadJobContext, BulkUploadHub>)x.GetService<IBulkUploadJob>());//Resolve previously queued job.

            services.AddSingleton<IProductionLearningStandardsJob, ProductionLearningStandardsJob>();
            services.AddSingleton(x => (WorkflowJob<LearningStandardsJobContext, ProductionLearningStandardsHub>) x.GetService<IProductionLearningStandardsJob>());//Resolve previously queued job.

#if NET48
            services.AddSingleton<ISecureHasher, Pbkdf2HmacSha1SecureHasher>();
#else
            // The intended type Pbkdf2HmacSha1SecureHasher relies on the NET48-only ODS
            // ChainOfResponsibilityFacility concept in the currently referenced version
            // of ODS Platform packages. This appears to the .NET Core IoC container as an
            // unresolvable circular dependency. Upon upgrading ODS Platform NuGet packages to
            // a higher, .NET Core-only version, we expect Pbkdf2HmacSha1SecureHasher's constructor
            // to simplify as it no longer uses ChainOfResponsibilityFacility and will no longer
            // present as a circular dependency. Until then, we register a stub alternative
            // to satisfy the IoC container. Upon upgrading packages, this and the stub class
            // should be removed in favor of registering Pbkdf2HmacSha1SecureHasher like NET48
            // above.
            //
            // Although the type is resolved at runtime, current code paths do not in fact invoke
            // methods on the type, so this does not pose an immediate risk of defects.
            services.AddSingleton<ISecureHasher, StubPbkdf2HmacSha1SecureHasher>();
#endif
            services.AddSingleton<IPackedHashConverter, PackedHashConverter>();
            services.AddSingleton<ISecurePackedHashProvider, SecurePackedHashProvider>();
            services.AddSingleton<IHashConfigurationProvider, DefaultHashConfigurationProvider>();

            InstallHostingSpecificClasses(services);

            services.AddScoped<InstanceContext>();

            services.AddTransient<ApplicationConfigurationService>();
            services.AddTransient<CloudOdsUpdateCheckService>();

            foreach (var type in typeof(IMarkerForEdFiOdsAdminAppManagement).Assembly.GetTypes())
            {
                if (type.IsClass && !type.IsAbstract && (type.IsPublic || type.IsNestedPublic))
                {
                    var concreteClass = type;

                    if (concreteClass == typeof(OdsApiFacade))
                        continue; //IOdsApiFacade is never resolved. Instead, classes inject IOdsApiFacadeFactory.

                    if (concreteClass == typeof(OdsRestClient))
                        continue; //IOdsRestClient is never resolved. Instead, classes inject IOdsRestClientFactory.

                    if (concreteClass == typeof(TokenRetriever))
                        continue; //ITokenRetriever is never resolved. Instead, other dependencies construct TokenRetriever directly.

                    var interfaces = concreteClass.GetInterfaces().ToArray();

                    if (interfaces.Length == 1)
                    {
                        var serviceType = interfaces.Single();

                        if (serviceType.FullName == $"{concreteClass.Namespace}.I{concreteClass.Name}")
                            services.AddTransient(serviceType, concreteClass);
                    }
                    else if (interfaces.Length == 0)
                    {
                        if (concreteClass.Name.EndsWith("Command") ||
                            concreteClass.Name.EndsWith("Query"))
                            services.AddTransient(concreteClass);
                    }
                }
            }

            services.AddSingleton<CloudOdsUpdateService>();

#if NET48
            services.Register(
                Classes.FromThisAssembly()
                    .BasedOn(typeof(IValidator<>))
                    .WithService
                    .Base()
                    .LifestyleTransient());
#endif
        }

#if NET48
        protected abstract void InstallHostingSpecificClasses(IWindsorContainer services);
#else
        protected abstract void InstallHostingSpecificClasses(IServiceCollection services);
#endif

#if NET48
        public static void ConfigureLearningStandards(IWindsorContainer services)
#else
        public static void ConfigureLearningStandards(IServiceCollection services)
#endif
        {
            var config = new EdFiOdsApiClientConfiguration(
                maxSimultaneousRequests: GetLearningStandardsMaxSimultaneousRequests());

            var serviceCollection = new ServiceCollection();

            var pluginConnector = new LearningStandardsCorePluginConnector(
                serviceCollection,
                ServiceProviderFunc,
                new LearningStandardLogProvider(),
                config
            );

            services.AddSingleton<ILearningStandardsCorePluginConnector>(pluginConnector);
        }

        private static int GetLearningStandardsMaxSimultaneousRequests()
        {
            const int IdealSimultaneousRequests = 4;
            const int PessimisticSimultaneousRequests = 1;

            try
            {
                var odsApiVersion = new InferOdsApiVersion().Version(CloudOdsAdminAppSettings.Instance.ProductionApiUrl);

                return odsApiVersion.StartsWith("3.") ? PessimisticSimultaneousRequests : IdealSimultaneousRequests;
            }
            catch (Exception e)
            {
                Logger.Warn(
                    "Failed to infer ODS / API version to determine Learning Standards " +
                    $"MaxSimultaneousRequests. Assuming a max of {PessimisticSimultaneousRequests}.", e);

                return PessimisticSimultaneousRequests;
            }
        }

        private static IServiceProvider ServiceProviderFunc(IServiceCollection collection)
        {
            return collection.BuildServiceProvider();
        }
    }
}
