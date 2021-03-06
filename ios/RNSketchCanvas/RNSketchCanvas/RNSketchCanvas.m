#import "RNSketchCanvasManager.h"
#import "RNSketchCanvas.h"
#import "RNSketchData.h"
#import "RNSketchCanvasDelegate.h"
#import <React/RCTEventDispatcher.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>
#import "Utility.h"

@implementation RNSketchCanvas
{
    RCTEventDispatcher *_eventDispatcher;
    NSMutableArray *_paths;
    RNSketchData *_currentPath;
    
    CAShapeLayer *_layer;
    RNSketchCanvasDelegate *delegate;
    
    CGRect _dirty;
}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _paths = [NSMutableArray new];
        _dirty = CGRectZero; //CGRectMake(0, 0, 0, 0);
    }
    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    if (!_layer) {
        CGRect bounds = self.bounds;
        
        delegate = [RNSketchCanvasDelegate new];
        _layer = [CAShapeLayer layer];
        _layer.frame = bounds;
        _layer.delegate = delegate;
        _layer.contentsScale = [UIScreen mainScreen].scale;
        
        delegate.paths = _paths;

        [self.layer addSublayer: _layer];
    }
}

- (void)newPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth {
    if (_currentPath) {
        [_currentPath end];
    }
    _currentPath = [[RNSketchData alloc]
                    initWithId: pathId
                    strokeColor: strokeColor
                    strokeWidth: strokeWidth];
    [_paths addObject: _currentPath];
}

- (void) addPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth points:(NSArray*) points {
    bool exist = false;
    for(int i=0; i<_paths.count; i++) {
        if (((RNSketchData*)_paths[i]).pathId == pathId) {
            exist = true;
            break;
        }
    }
    
    if (!exist) {
        RNSketchData *data = [[RNSketchData alloc] initWithId: pathId
                                                  strokeColor: strokeColor
                                                  strokeWidth: strokeWidth
                                                       points: points];
        [_paths addObject: data];
        [self invalidate];
    }
}

- (void)deletePath:(int) pathId {
    int index = -1;
    for(int i=0; i<_paths.count; i++) {
        if (((RNSketchData*)_paths[i]).pathId == pathId) {
            index = i;
            break;
        }
    }
    
    if (index > -1) {
        [_paths removeObjectAtIndex: index];
        [self invalidate];
    }
}

- (void)addPointX: (float)x Y: (float)y {
    [_currentPath addPoint: CGPointMake(x, y)];
    if (CGRectIsEmpty(_dirty)) {
        _dirty = CGRectMake(x, y, 1, 1);
        [self invalidateInRect: CGRectMake(x - _currentPath.strokeWidth, y -_currentPath.strokeWidth,
                                           2 * _currentPath.strokeWidth, 2 * _currentPath.strokeWidth)];
    } else {
        _dirty = CGRectMake(
                            MIN(x, CGRectGetMinX(_dirty)),
                            MIN(y, CGRectGetMinY(_dirty)),
                            MAX(x, CGRectGetMaxX(_dirty)) - MIN(x, CGRectGetMinX(_dirty)),
                            MAX(y, CGRectGetMaxY(_dirty)) - MIN(y, CGRectGetMinY(_dirty))
                            );
        [self invalidateInRect: CGRectInset(_dirty, -_currentPath.strokeWidth * 2, -_currentPath.strokeWidth * 2)];
    }
}

- (void)endPath {
    if (_currentPath) {
        [_currentPath end];
        _currentPath = nil;
        [self invalidate];
    }
}

- (void) clear {
    [_paths removeAllObjects];
    _currentPath = nil;
    [self invalidate];
}

- (void) saveImageOfType: (NSString*) type withTransparentBackground: (BOOL) transparent {
    CGRect rect = _layer.frame;
    UIGraphicsBeginImageContextWithOptions(rect.size, !transparent, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if ([type isEqualToString: @"png"] && !transparent) {
        CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
        CGContextFillRect(context, CGRectMake(0, 0, rect.size.width, rect.size.height));
    }
    [_layer renderInContext:context];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if ([type isEqualToString: @"jpg"]) {
        UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    } else {
        UIImageWriteToSavedPhotosAlbum([UIImage imageWithData: UIImagePNGRepresentation(img)], self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }
}

- (NSString*) transferToBase64OfType: (NSString*) type withTransparentBackground: (BOOL) transparent {
    CGRect rect = _layer.frame;
    UIGraphicsBeginImageContextWithOptions(rect.size, !transparent, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if ([type isEqualToString: @"png"] && !transparent) {
        CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
        CGContextFillRect(context, CGRectMake(0, 0, rect.size.width, rect.size.height));
    }
    [_layer renderInContext:context];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if ([type isEqualToString: @"jpg"]) {
        return [UIImageJPEGRepresentation(img, 0.9) base64EncodedStringWithOptions: NSDataBase64Encoding64CharacterLineLength];
    } else {
        return [UIImagePNGRepresentation(img) base64EncodedStringWithOptions: NSDataBase64Encoding64CharacterLineLength];
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo: (void *) contextInfo {
    if (_onChange) {
        _onChange(@{ @"success": error != nil ? @NO : @YES });
    }
}

- (void) invalidate {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_onChange) {
            _onChange(@{ @"pathsUpdate": @(_paths.count) });
        }
        [_layer setNeedsDisplay];
    });
}

- (void) invalidateInRect: (CGRect) rect {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_layer setNeedsDisplayInRect: rect ];
    });
}



#pragma CALayerDelegate


@end
