//
//  RecentMsgViewController.m
//  XMPPChat
//
//  Created by 马远征 on 14-3-31.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "RecentMsgViewController.h"
#import "YZChatViewController.h"
#import "YZRecentChatListCell.h"
#import <XMPPMessageArchiving_Contact_CoreDataObject.h>

@interface RecentMsgViewController ()
<UITableViewDelegate,UITableViewDataSource,NSFetchedResultsControllerDelegate>
{
    NSFetchedResultsController *_fetchedResultsController;
}
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation RecentMsgViewController

#pragma mark -
#pragma mark dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark -
#pragma mark init

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.title = @"消息";
    }
    return self;
}


#pragma mark -
#pragma mark loadView

- (void)loadView
{
    [super loadView];
    UIView *contentView = [[UIView alloc]initWithFrame:[[UIScreen mainScreen]applicationFrame]];
    contentView.backgroundColor = [UIColor whiteColor];
    self.view = contentView;
}


- (void)initRightBarButton
{
    UIImage *image = [UIImage imageNamed:@"Add"];
    UIButton *buton = [UIButton buttonWithType:UIButtonTypeCustom];
    [buton setFrame:CGRectMake(0, 0, image.size.width, image.size.height)];
    [buton setBackgroundImage:image forState:UIControlStateNormal];
    [buton addTarget:self action:@selector(clickToChatWithBuddy) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:buton];
}

- (void)initTableView
{
    _tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, KScreenWidth, KScreenHeight - 114)];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
}


- (NSFetchedResultsController *)fetchedResultsController
{
    if (nil != _fetchedResultsController)
    {
        return _fetchedResultsController;
    }
    
    XMPPMessageArchivingCoreDataStorage *storage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
    NSManagedObjectContext *moc = [storage mainThreadManagedObjectContext];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"XMPPMessageArchiving_Contact_CoreDataObject"
                                                         inManagedObjectContext:moc];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
    [fetchRequest setEntity:entityDescription];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"mostRecentMessageTimestamp" ascending:NO];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    
    
    YZXMPPManager *xmppMgr = [YZXMPPManager sharedYZXMPP];
    NSString *streamBareJidStr = xmppMgr.xmppStream.myJID.bare;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"streamBareJidStr == %@",streamBareJidStr];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setFetchBatchSize:20];
    
//    NSArray *array = [moc executeFetchRequest:fetchRequest error:nil];
//    NSLog(@"---%s--%@",__FUNCTION__,array);
    
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

- (void)registerNotification
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(receiveRefreshNotify)
                                                name:@"EVENT_CONTACT_REFRESH_NOTIFY" object:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initRightBarButton];
    [self initTableView];
    [self registerNotification];
}

- (void)receiveRefreshNotify
{
    _fetchedResultsController = nil;
    [self.tableView reloadData];
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
//    NSLog(@"---%s---",__FUNCTION__);
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
//    NSLog(@"---%s---",__FUNCTION__);
    [self.tableView reloadData];
}



- (void)clickToChatWithBuddy
{
    
}

#pragma mark -
#pragma mark UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[self.fetchedResultsController sections] objectAtIndex:section] numberOfObjects];;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    YZRecentChatListCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[YZRecentChatListCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    XMPPMessageArchiving_Contact_CoreDataObject *contactObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.imageView.image = [UIImage imageNamed:@"avatar_default"];
    cell.textLabel.text = contactObject.bareJid.user;
    cell.detailTextLabel.text = contactObject.mostRecentMessageBody;
    cell.timeStampLabel.text = [NSString stringWithFormat:@"%@",contactObject.mostRecentMessageTimestamp];
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    XMPPMessageArchiving_Contact_CoreDataObject *contactObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (contactObject.bareJid)
    {
        YZChatViewController *chatVC = [[YZChatViewController alloc]initWithXmppJID:contactObject.bareJid];
        chatVC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:chatVC animated:YES];
        chatVC = nil;
    }
}

@end
