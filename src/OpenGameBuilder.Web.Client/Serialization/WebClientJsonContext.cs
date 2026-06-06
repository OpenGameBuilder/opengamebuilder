using System.Text.Json.Serialization;
using OpenGameBuilder.Api.Contracts.Diagnostics;

namespace OpenGameBuilder.Web.Client.Serialization;

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase, PropertyNameCaseInsensitive = true)]
[JsonSerializable(typeof(ClientLogEntry))]
internal sealed partial class WebClientJsonContext : JsonSerializerContext
{ }
