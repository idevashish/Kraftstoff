// FuelStatisticsViewController.h
//
// Kraftstoff



#pragma mark -
#pragma mark Base Statistics View Controller



@interface FuelStatisticsViewController : UIViewController
{
    NSMutableDictionary *contentCache;
    NSInteger  displayedNumberOfMonths;
    NSInteger  invalidationCounter;
}

- (IBAction)checkboxButton: (UIButton*)sender;

- (void)invalidateCaches;
- (void)purgeDiscardableCacheContent;

@property (nonatomic, strong) NSManagedObject *selectedCar;
@property (nonatomic)         BOOL             active;

@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *activityView;

@property (nonatomic, strong) IBOutlet UILabel *leftLabel;
@property (nonatomic, strong) IBOutlet UILabel *rightLabel;
@property (nonatomic, strong) IBOutlet UILabel *centerLabel;

@property (nonatomic)         BOOL     zooming;
@property (nonatomic, strong) UILongPressGestureRecognizer *zoomRecognizer;

@end



#pragma mark -
#pragma mark Subclasses for Statistics Pages



@interface FuelStatisticsViewController_AvgConsumption : FuelStatisticsViewController {}
@end

@interface FuelStatisticsViewController_PriceAmount : FuelStatisticsViewController {}
@end

@interface FuelStatisticsViewController_PriceDistance : FuelStatisticsViewController {}
@end



#pragma mark -
#pragma mark Disposable Content Objects Entry for NSCache



#define MAX_SAMPLES   128

@interface FuelStatisticsSamplingData : NSObject
{
@public

    // Curve data
    CGPoint   data [MAX_SAMPLES];
    NSInteger dataCount;

    // Lens data
    NSTimeInterval lensDate [MAX_SAMPLES][2];
    CGFloat lensValue [MAX_SAMPLES];

    // Data for marker positions
    CGFloat   hMarkPositions [5];
    NSString* hMarkNames [5];
    NSInteger hMarkCount;

    CGFloat   vMarkPositions [3];
    NSString* vMarkNames [3];
    NSInteger vMarkCount;
}

@property (nonatomic, strong) UIImage  *contentImage;
@property (nonatomic, strong) NSNumber *contentAverage;

@end
