import os

AUDIO_EXTENSION_TO_MIME: dict[str, str] = {
    ".m4a": "audio/m4a",
    ".mp4": "audio/mp4",
    ".wav": "audio/wav",
    ".aac": "audio/aac",
    ".webm": "audio/webm",
    ".mp3": "audio/mp3",
    ".mpeg": "audio/mpeg",
    ".ogg": "audio/ogg",
    ".oga": "audio/ogg",
    ".opus": "audio/opus",
    ".flac": "audio/flac",
}


def resolve_audio_mime_type(
    content_type: str | None,
    filename: str | None = None,
    default_mime: str = "audio/m4a",
) -> str:
    """Resolves the audio MIME type from content_type header or filename extension.

    Avoids blindly trusting 'application/octet-stream' when the filename or recording
    configuration provides the real audio format.
    """
    if content_type:
        clean_ct = content_type.strip().lower()
        # Accept valid audio MIME types directly
        if clean_ct.startswith("audio/"):
            return clean_ct

    # If content_type is missing or generic (e.g. application/octet-stream), check filename extension
    if filename:
        _, ext = os.path.splitext(filename)
        ext_lower = ext.lower()
        if ext_lower in AUDIO_EXTENSION_TO_MIME:
            return AUDIO_EXTENSION_TO_MIME[ext_lower]

    return default_mime
