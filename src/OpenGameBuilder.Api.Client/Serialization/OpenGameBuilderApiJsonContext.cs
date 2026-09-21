using System.Text.Json.Serialization;
using OpenGameBuilder.Api.Contracts.About;

namespace OpenGameBuilder.Api.Client.Serialization;

[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    PropertyNameCaseInsensitive = true,
    RespectNullableAnnotations = true)]
[JsonSerializable(typeof(AboutResponse))]
internal sealed partial class OpenGameBuilderApiJsonContext : JsonSerializerContext;
