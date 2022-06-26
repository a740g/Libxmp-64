'---------------------------------------------------------------------------------------------------------
' LibXMP Lite
' Copyright (c) 2022 Samuel Gomes
'---------------------------------------------------------------------------------------------------------

'---------------------------------------------------------------------------------------------------------
' HEADER FILES
'---------------------------------------------------------------------------------------------------------
'$Include:'Common.bi'
'---------------------------------------------------------------------------------------------------------

$If LIBXMPLITE_BI = UNDEFINED Then
    $Let LIBXMPLITE_BI = TRUE
    '-----------------------------------------------------------------------------------------------------
    ' CONSTANTS
    '-----------------------------------------------------------------------------------------------------
    Const XMP_PLAYER_VOLUME = 7 ' Player module volume

    Const XMP_SOUND_BUFFER_CHANNELS = 2 ' 2 channel (stereo)
    Const XMP_SOUND_BUFFER_CHANNEL_SAMPLE_BYTES = 2 ' 2 bytes (16-bits signed integer)
    Const XMP_SOUND_BUFFER_SAMPLE_SIZE = XMP_SOUND_BUFFER_CHANNELS + XMP_SOUND_BUFFER_CHANNEL_SAMPLE_BYTES
    Const XMP_SOUND_BUFFER_SIZE_MULTIPLIER = 0.02322 ' This is what we will multiply the buffer size with to get the final size
    Const XMP_SOUND_TIME_MIN = 0.2 ' We will check that we have this amount of time left in the QB64 sound pipe
    '-----------------------------------------------------------------------------------------------------

    '-----------------------------------------------------------------------------------------------------
    ' USER DEFINED TYPES
    '-----------------------------------------------------------------------------------------------------
    ' Info type used with xmp_get_frame_info()
    Type xmp_frame_info
        position As Long ' Current position
        pattern As Long ' Current pattern
        row As Long ' Current row in pattern
        num_rows As Long ' Number of rows in current pattern
        frame As Long ' Current frame
        speed As Long ' Current replay speed
        bpm As Long ' Current bpm
        time As Long ' Current module time in ms
        total_time As Long ' Estimated replay time in ms*/
        frame_time As Long ' Frame replay time in us
        buffer As Offset ' Pointer to sound buffer
        buffer_size As Long ' Used buffer size
        total_size As Long ' Total buffer size
        volume As Long ' Current master volume
        loop_count As Long ' Loop counter
        virt_channels As Long ' Number of virtual channels
        virt_used As Long ' Used virtual channels
        sequence As Long ' Current sequence
        channel_info As String * 1536 ' Current channel info (embedded struct xmp_channel_info array)
    End Type

    ' QB64 specific stuff
    Type XMPPlayerType
        context As Offset ' This is a libxmp context
        isPlaying As Byte ' Set to true if tune is playing
        isPaused As Byte ' Set to true if tune is paused
        isLooping As Byte ' Set to true if tune is looping
        frame As xmp_frame_info ' Current frame info. This is used to check if we are looping or playback is done
        errorCode As Long ' This hold the error code from a previous XMP function
        soundBuffer As MEM ' This is the buffer that holds the rendered samples from libxmp
        soundBufferSize As Unsigned Long ' Size of the render buffer
        soundHandle As Long ' The sound pipe that we wll use to play the rendered samples
    End Type
    '-----------------------------------------------------------------------------------------------------

    '-----------------------------------------------------------------------------------------------------
    ' EXTERNAL LIBRARIES
    '-----------------------------------------------------------------------------------------------------
    Declare Static Library "./libxmp"
        Function xmp_create_context%&
        Sub xmp_free_context (ByVal context As Offset)
        Function xmp_load_module& (ByVal context As Offset, path As String)
        Sub xmp_release_module (ByVal context As Offset)
        Function xmp_start_player& (ByVal context As Offset, Byval rate As Long, Byval format As Long)
        Sub xmp_end_player (ByVal context As Offset)
        Function xmp_play_buffer& (ByVal context As Offset, Byval buffer As Offset, Byval size As Long, Byval loops As Long)
        Sub xmp_get_frame_info (ByVal context As Offset, frame_info As xmp_frame_info)
        Function xmp_get_player& (ByVal context As Offset, Byval param As Long)
        Function xmp_set_player& (ByVal context As Offset, Byval param As Long, Byval value As Long)
    End Declare
    '-----------------------------------------------------------------------------------------------------

    '-----------------------------------------------------------------------------------------------------
    ' GLOBAL VARIABLES
    '-----------------------------------------------------------------------------------------------------
    Dim Shared XMPPlayer As XMPPlayerType
    '-----------------------------------------------------------------------------------------------------
$End If
'---------------------------------------------------------------------------------------------------------

