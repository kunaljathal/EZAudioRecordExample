//
//  RecordViewController.m
//  EZAudioRecordExample
//
//  Created by Syed Haris Ali on 12/15/13.
//  Copyright (c) 2013 Syed Haris Ali. All rights reserved.
//

#import "RecordViewController.h"

@interface RecordViewController () <MFMailComposeViewControllerDelegate>
// Using AVPlayer for example
@property (nonatomic,strong) AVAudioPlayer *audioPlayer;
@property (nonatomic,weak) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UILabel *accelerometerValue;
@property (nonatomic,weak) IBOutlet UISwitch *recordSwitch;
@property (nonatomic,weak) IBOutlet UILabel *recordingTextField;
@property (strong, nonatomic) NSMutableArray *accelerometerLog;
@property (nonatomic) BOOL logData;
@end

@implementation RecordViewController
@synthesize audioPlot;
@synthesize microphone;
@synthesize playButton;
@synthesize recorder;
@synthesize recordSwitch;
@synthesize recordingTextField;

#pragma mark - Initialization
-(id)init {
  self = [super init];
  if(self){
    [self initializeViewController];
  }
  return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if(self){
    [self initializeViewController];
  }
  return self;
}

#pragma mark - Initialize View Controller Here
-(void)initializeViewController {
    // Create an instance of the microphone and tell it to use this view controller instance as the delegate
    self.microphone = [EZMicrophone microphoneWithDelegate:self];
    
    
}

#pragma mark - Customize the Audio Plot
-(void)viewDidLoad {
  
  [super viewDidLoad];
  
  /*
   Customizing the audio plot's look
   */
  // Background color
  self.audioPlot.backgroundColor = [UIColor colorWithRed: 0.984 green: 0.71 blue: 0.365 alpha: 1];
  // Waveform color
  self.audioPlot.color           = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
  // Plot type
  self.audioPlot.plotType        = EZPlotTypeRolling;
  // Fill
  self.audioPlot.shouldFill      = YES;
  // Mirror
  self.audioPlot.shouldMirror    = YES;
  
  /*
   Start the microphone
   */
  [self.microphone startFetchingAudio];
  self.recordingTextField.text = @"Not Recording";
  
  // Hide the play button
  self.playButton.hidden = YES;
  
    self.logData = NO;


    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.accelerometerUpdateInterval = 1/600;

    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue]
                                             withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                                                 [self outputAccelerationData:accelerometerData.acceleration];
                                                 if(error){
                                                     NSLog(@"%@", error);
                                                 }
                                             }];

    self.accelerometerLog = [[NSMutableArray alloc] init];

    
  /*
   Log out where the file is being written to within the app's documents directory
   */
  NSLog(@"File written to application sandbox's documents directory: %@",[self testFilePathURL]);
  
}

#pragma mark - Actions
-(void)playFile:(id)sender
{
    // Update microphone state
    [self.microphone stopFetchingAudio];

    // Update recording state
    self.isRecording = NO;
    self.recordingTextField.text = @"Not Recording";
    self.recordSwitch.on = NO;

    // Create Audio Player
    if( self.audioPlayer )
    {
        if( self.audioPlayer.playing )
        {
            [self.audioPlayer stop];
        }
        self.audioPlayer = nil;
    }

    // Close the audio file
    if( self.recorder )
    {
        [self.recorder closeAudioFile];
    }
    
    if ([MFMailComposeViewController canSendMail])
    {
        NSArray *arrayPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
        NSString *docDir = [arrayPaths objectAtIndex:0];
        NSString *Path = [docDir stringByAppendingString:@"/components.csv"];
        
        // write the contents of the accelerometer log to a csv file.
        [[self.accelerometerLog componentsJoinedByString:@",\n"] writeToFile:Path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        
        NSData *audioData = [NSData dataWithContentsOfURL:[self testFilePathURL]];
        NSData *csvData = [NSData dataWithContentsOfFile:Path];
        
        NSArray *sendTo = [NSArray arrayWithObject:@"Kunal Jathal <kunal.jathal@gmail.com>"];
        MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
        mailViewController.mailComposeDelegate = self;
        [mailViewController setSubject:@"Log"];
        [mailViewController setMessageBody:@"Accelerometer Log and Audio Recording" isHTML:NO];
        [mailViewController setToRecipients:sendTo];
        [mailViewController addAttachmentData:audioData
                                     mimeType:@"audio/wav"
                                     fileName:kAudioFilePath];
    
        [mailViewController addAttachmentData:csvData
                                     mimeType:@"text/csv"
                                     fileName:@"components.csv"];
        
        [self presentViewController:mailViewController animated:YES completion:nil];
    }
}


- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

-(void)toggleMicrophone:(id)sender {
  
  if( self.audioPlayer ){
    if( self.audioPlayer.playing ) [self.audioPlayer stop];
    self.audioPlayer = nil;
  }
  
  if( ![(UISwitch*)sender isOn] ){
    [self.microphone stopFetchingAudio];
  }
  else {
    [self.microphone startFetchingAudio];
  }
}

-(void)toggleRecording:(id)sender {
  
    if( self.audioPlayer )
    {
        if( self.audioPlayer.playing )
        {
            [self.audioPlayer stop];
        }
        self.audioPlayer = nil;
    }
    self.playButton.hidden = NO;
    
    if( [sender isOn] )
    {
        /*
         Create the recorder
         */
        self.recorder = [EZRecorder recorderWithDestinationURL:[self testFilePathURL]
                                                  sourceFormat:self.microphone.audioStreamBasicDescription
                                           destinationFileType:EZRecorderFileTypeWAV];
    }
    else
    {
        [self.recorder closeAudioFile];
    }
    self.isRecording = (BOOL)[sender isOn];
    self.recordingTextField.text = self.isRecording ? @"Recording" : @"Not Recording";
    
    
    self.logData = [(UISwitch *)sender isOn];
}

#pragma mark - EZMicrophoneDelegate
#warning Thread Safety
// Note that any callback that provides streamed audio data (like streaming microphone input) happens on a separate audio thread that should not be blocked. When we feed audio data into any of the UI components we need to explicity create a GCD block on the main thread to properly get the UI to work.
-(void)microphone:(EZMicrophone *)microphone
 hasAudioReceived:(float **)buffer
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
  // Getting audio data as an array of float buffer arrays. What does that mean? Because the audio is coming in as a stereo signal the data is split into a left and right channel. So buffer[0] corresponds to the float* data for the left channel while buffer[1] corresponds to the float* data for the right channel.
  
  // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
  dispatch_async(dispatch_get_main_queue(),^{
    // All the audio plot needs is the buffer data (float*) and the size. Internally the audio plot will handle all the drawing related code, history management, and freeing its own resources. Hence, one badass line of code gets you a pretty plot :)
    [self.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
  });
}

-(void)microphone:(EZMicrophone *)microphone
    hasBufferList:(AudioBufferList *)bufferList
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
  
  // Getting audio data as a buffer list that can be directly fed into the EZRecorder. This is happening on the audio thread - any UI updating needs a GCD main queue block. This will keep appending data to the tail of the audio file.
  if( self.isRecording ){
    [self.recorder appendDataFromBufferList:bufferList
                             withBufferSize:bufferSize];
  }
  
}

#pragma mark - AVAudioPlayerDelegate
/*
 Occurs when the audio player instance completes playback
 */
-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
  self.audioPlayer = nil;
  
  [self.microphone startFetchingAudio];
}

#pragma mark - Utility
-(NSArray*)applicationDocuments {
  return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
}

-(NSString*)applicationDocumentsDirectory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
  return basePath;
}

-(NSURL*)testFilePathURL {
  return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",
                                 [self applicationDocumentsDirectory],
                                 kAudioFilePath]];
}

-(void)outputAccelerationData:(CMAcceleration)acceleration
{
    self.accelerometerValue.text = [NSString stringWithFormat:@" %f",acceleration.z];
    
    if (self.logData)
    {
        [self.accelerometerLog addObject:[NSString stringWithFormat:@"%f",acceleration.z]];
        
        NSTimeInterval hello = self.motionManager.deviceMotion.timestamp;
        
        [self.accelerometerLog addObject:[NSString stringWithFormat:@"%f\n", hello]];
    }

}

@end
