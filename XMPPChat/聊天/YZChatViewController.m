//
//  YZChatViewController.m
//  XMPPChat
//
//  Created by 马远征 on 14-4-1.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "YZChatViewController.h"
#import "YZChatToolBarView.h"
#import "YZXMPPManager.h"
#import <XMPPMessageArchiving_Message_CoreDataObject.h>

@interface YZChatViewController () <UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate,YZChatToolBarDeleagte,
UINavigationControllerDelegate,UIImagePickerControllerDelegate,UIActionSheetDelegate,NSFetchedResultsControllerDelegate>
{
    NSFetchedResultsController *_fetchedResultsController;
}
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) YZChatToolBarView *toolBarView;
@property (nonatomic, strong) XMPPJID *xmppJID;

@end

@implementation YZChatViewController

#pragma mark -
#pragma mark dealloc

- (void)dealloc
{
    _tableView = nil;
    _toolBarView = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark -
#pragma mark init

- (id)initWithXmppJID:(XMPPJID *)xmppJID
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _xmppJID = xmppJID;
        self.title = _xmppJID.user;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    UIView *contentView = [[UIView alloc]initWithFrame:[[UIScreen mainScreen]applicationFrame]];
    contentView.backgroundColor = [UIColor whiteColor];
    self.view = contentView;
}

- (void)initTableView
{
    _tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, KScreenWidth, KScreenHeight - 114) style:UITableViewStylePlain];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = nil;
    _tableView.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"chat_bg_default.jpg"]];
    _tableView.allowsSelection = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.scrollsToTop = YES;
    [self.view addSubview:_tableView];
}


- (void)initChatToolBarView
{
    CGRect frame = CGRectMake(0, KScreenHeight - 114, KScreenWidth, 266);
    _toolBarView = [[YZChatToolBarView alloc]initWithFrame:frame];
    _toolBarView.delegate = self;
    [self.view addSubview:_toolBarView];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (nil != _fetchedResultsController)
    {
        return _fetchedResultsController;
    }
    
    XMPPMessageArchivingCoreDataStorage *storage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
    NSManagedObjectContext *moc = [storage mainThreadManagedObjectContext];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"XMPPMessageArchiving_Message_CoreDataObject"
                                                         inManagedObjectContext:moc];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
    [fetchRequest setEntity:entityDescription];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    YZXMPPManager *xmppMgr = [YZXMPPManager sharedYZXMPP];
    NSString *streamBareJidStr = xmppMgr.xmppStream.myJID.bare;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@ AND streamBareJidStr == %@", _xmppJID.bare,streamBareJidStr];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setFetchBatchSize:20];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                    managedObjectContext:moc
                                                                      sectionNameKeyPath:nil
                                                                               cacheName:nil];
    _fetchedResultsController.delegate = self;
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error])
    {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    NSLog(@"---%s---",__FUNCTION__);
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    NSLog(@"---%s---",__FUNCTION__);
    [self.tableView reloadData];
}



- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initTableView];
    [self initChatToolBarView];
}


#pragma mark -
#pragma mark UIScrollView Delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.view endEditing:YES];
    [_toolBarView TBScrollViewWillBeginDragging:scrollView];
}

#pragma mark -
#pragma mark YZChatToolBarDeleagte

- (void)YZChatTextViewDidSend:(NSString *)text
{
    DEBUG_METHOD(@"-%s-%@",__func__,text);
    [[YZXMPPManager sharedYZXMPP]sendMessage:text toUser:_xmppJID.user];
    
}

- (void)YZChatToolBoxButtonClick:(NSUInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        UIImagePickerController *pickerController = [[UIImagePickerController alloc]init];
        pickerController.delegate = self;
        pickerController.allowsEditing = YES;
        pickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        pickerController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        if ([self.navigationController respondsToSelector:@selector(presentViewController:animated:completion:)])
        {
            [self.navigationController presentViewController:pickerController animated:YES completion:^{}];
        }
        else
        {
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
            [self.navigationController presentModalViewController:pickerController animated:YES];
#endif
        }

    }
}

-(void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info
{
    if ([picker respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
    {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        [picker dismissModalViewControllerAnimated:YES];
    }
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    NSData *imagedata = UIImagePNGRepresentation(image);
    XMPPJID *jid = [XMPPJID jidWithString:[NSString stringWithFormat:@"%@@%@/%@",_xmppJID.user,KXMPPHostName,KXMPPResource]];
    [[YZXMPPManager sharedYZXMPP]sendImage:imagedata Jid:jid];
    // 发送照片
    
}


-(void)imagePickerControllerDidCancel:(UIImagePickerController*)picker
{
    if ([picker respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
    {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        [picker dismissModalViewControllerAnimated:YES];
    }
}


#pragma mark -
#pragma mark UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[self.fetchedResultsController sections] objectAtIndex:section] numberOfObjects];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    XMPPMessageArchiving_Message_CoreDataObject *msgObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = msgObject.body;
    return cell;
}

@end
