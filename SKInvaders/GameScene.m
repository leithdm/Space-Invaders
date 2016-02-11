//
//  GameScene.m
//  SKInvaders
//

#import "GameScene.h"
#import <CoreMotion/CoreMotion.h>
#import "GameOverScene.h"

#pragma mark - Custom Type Definitions

//1
typedef enum InvaderType {
	InvaderTypeA,
	InvaderTypeB,
	InvaderTypeC
} InvaderType;

typedef enum InvaderMovementDirection {
	InvaderMovementDirectionRight,
	InvaderMovementDirectionLeft,
	InvaderMovementDirectionDownThenRight,
	InvaderMovementDirectionDownThenLeft,
	InvaderMovementDirectionNone
} InvaderMovementDirection;

typedef enum BulletType {
	ShipFiredBulletType,
	InvaderFiredBulletType
} BulletType;

static const u_int32_t kInvaderCategory            = 0x1 << 0;
static const u_int32_t kShipFiredBulletCategory    = 0x1 << 1;
static const u_int32_t kShipCategory               = 0x1 << 2;
static const u_int32_t kSceneEdgeCategory          = 0x1 << 3;
static const u_int32_t kInvaderFiredBulletCategory = 0x1 << 4;

//2
#define kInvaderSize CGSizeMake(24, 16)
#define kInvaderGridSpacing CGSizeMake(12, 12)
#define kInvaderRowCount 6
#define kInvaderColCount 6
//3
#define kInvaderName @"invader"
#define kShipSize CGSizeMake(30, 16)
#define kShipName @"ship"
#define kScoreHudName @"scoreHud"
#define kHealthHudName @"healthHud"
#define kMinInvaderBottomHeight 2 * kShipSize.height

#define kShipFiredBulletName @"shipFiredBullet"
#define kInvaderFiredBulletName @"invaderFiredBullet"
#define kBulletSize CGSizeMake(4, 8)

#pragma mark - Private GameScene Properties

@interface GameScene ()
@property BOOL contentCreated;
@property InvaderMovementDirection invaderMovementDirection;
@property NSTimeInterval timeOfLastMove;
@property NSTimeInterval timePerMove;
@property (strong) CMMotionManager* motionManager;
@property (strong) NSMutableArray* tapQueue;
@property (strong) NSMutableArray* contactQueue;
@property NSUInteger score;
@property CGFloat shipHealth;
@property BOOL gameEnding;
@end


@implementation GameScene

#pragma mark Object Lifecycle Management

#pragma mark - Scene Setup and Content Creation

- (void)didMoveToView:(SKView *)view
{
	if (!self.contentCreated) {
		[self createContent];
		self.contentCreated = YES;
		self.motionManager = [[CMMotionManager alloc] init];
		[self.motionManager startAccelerometerUpdates];
		self.tapQueue = [NSMutableArray array];
		self.userInteractionEnabled = YES;
		self.contactQueue = [NSMutableArray array];
		self.physicsWorld.contactDelegate = self;
	}
}

- (void)createContent
{
	//1
	self.invaderMovementDirection = InvaderMovementDirectionRight;
	//2
	self.timePerMove = 1.0;
	//3
	self.timeOfLastMove = 0.0;

	self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
	self.physicsBody.categoryBitMask = kSceneEdgeCategory;

	[self setupInvaders];
	[self setupShip];
	[self setupHud];
}

-(NSArray*)loadInvaderTexturesOfType:(InvaderType)invaderType {
	NSString* prefix;
	switch (invaderType) {
		case InvaderTypeA:
			prefix = @"InvaderA";
			break;
		case InvaderTypeB:
			prefix = @"InvaderB";
			break;
		case InvaderTypeC:
		default:
			prefix = @"InvaderC";
			break;
	}
	//1
	return @[[SKTexture textureWithImageNamed:[NSString stringWithFormat:@"%@_00.png", prefix]],
			 [SKTexture textureWithImageNamed:[NSString stringWithFormat:@"%@_01.png", prefix]]];
}

-(SKNode*)makeInvaderOfType:(InvaderType)invaderType {
	NSArray* invaderTextures = [self loadInvaderTexturesOfType:invaderType];
	//2
	SKSpriteNode* invader = [SKSpriteNode spriteNodeWithTexture:[invaderTextures firstObject]];
	invader.name = kInvaderName;
	//3
	[invader runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:invaderTextures timePerFrame:self.timePerMove]]];

	invader.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:invader.frame.size];
	invader.physicsBody.dynamic = NO;
	invader.physicsBody.categoryBitMask = kInvaderCategory;
	invader.physicsBody.contactTestBitMask = 0x0;
	invader.physicsBody.collisionBitMask = 0x0;

	return invader;
}

-(void)setupInvaders {
	//1
	CGPoint baseOrigin = CGPointMake(kInvaderSize.width / 2, 180);
	for (NSUInteger row = 0; row < kInvaderRowCount; ++row) {
		//2
		InvaderType invaderType;
		if (row % 3 == 0)      invaderType = InvaderTypeA;
		else if (row % 3 == 1) invaderType = InvaderTypeB;
		else                   invaderType = InvaderTypeC;

		//3
		CGPoint invaderPosition = CGPointMake(baseOrigin.x, row * (kInvaderGridSpacing.height + kInvaderSize.height) + baseOrigin.y);

		//4
		for (NSUInteger col = 0; col < kInvaderColCount; ++col) {
			//5
			SKNode* invader = [self makeInvaderOfType:invaderType];
			invader.position = invaderPosition;
			[self addChild:invader];
			//6
			invaderPosition.x += kInvaderSize.width + kInvaderGridSpacing.width;
		}
	}
}

-(void)setupShip {
	//1
	SKNode* ship = [self makeShip];
	//2
	ship.position = CGPointMake(self.size.width / 2.0f, kShipSize.height/2.0f);
	[self addChild:ship];
	self.shipHealth = 1.0f;
}

-(SKNode*)makeShip {
	//1
	SKSpriteNode* ship = [SKSpriteNode spriteNodeWithImageNamed:@"Ship.png"];
	ship.name = kShipName;
	//2
	ship.color = [UIColor greenColor];
	ship.colorBlendFactor = 1.0f;
	ship.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:ship.frame.size];
	ship.physicsBody.dynamic = YES;
	ship.physicsBody.affectedByGravity = NO;
	ship.physicsBody.mass = 0.02;
	ship.physicsBody.categoryBitMask = kShipCategory;
	ship.physicsBody.contactTestBitMask = 0x0;
	ship.physicsBody.collisionBitMask = kSceneEdgeCategory;

	return ship;
}

-(void)setupHud {
	SKLabelNode* scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"Courier"];
	//1
	scoreLabel.name = kScoreHudName;
	scoreLabel.fontSize = 15;
	//2
	scoreLabel.fontColor = [SKColor greenColor];
	scoreLabel.text = [NSString stringWithFormat:@"Score: %04u", 0];
	//3
	scoreLabel.position = CGPointMake(20 + scoreLabel.frame.size.width/2, self.size.height - (20 + scoreLabel.frame.size.height/2));
	[self addChild:scoreLabel];

	SKLabelNode* healthLabel = [SKLabelNode labelNodeWithFontNamed:@"Courier"];
	//4
	healthLabel.name = kHealthHudName;
	healthLabel.fontSize = 15;
	//5
	healthLabel.fontColor = [SKColor redColor];
	healthLabel.text = [NSString stringWithFormat:@"Health: %.1f%%", self.shipHealth * 100.0f];
	//6
	healthLabel.position = CGPointMake(self.size.width - healthLabel.frame.size.width/2 - 20, self.size.height - (20 + healthLabel.frame.size.height/2));
	[self addChild:healthLabel];
}

-(SKNode*)makeBulletOfType:(BulletType)bulletType {
	SKNode* bullet;

	switch (bulletType) {
		case ShipFiredBulletType:
			bullet = [SKSpriteNode spriteNodeWithColor:[SKColor greenColor] size:kBulletSize];
			bullet.name = kShipFiredBulletName;
			bullet.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:bullet.frame.size];
			bullet.physicsBody.dynamic = YES;
			bullet.physicsBody.affectedByGravity = NO;
			bullet.physicsBody.categoryBitMask = kShipFiredBulletCategory;
			bullet.physicsBody.contactTestBitMask = kInvaderCategory;
			bullet.physicsBody.collisionBitMask = 0x0;
			break;
		case InvaderFiredBulletType:
			bullet = [SKSpriteNode spriteNodeWithColor:[SKColor magentaColor] size:kBulletSize];
			bullet.name = kInvaderFiredBulletName;
			bullet.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:bullet.frame.size];
			bullet.physicsBody.dynamic = YES;
			bullet.physicsBody.affectedByGravity = NO;
			bullet.physicsBody.categoryBitMask = kInvaderFiredBulletCategory;
			bullet.physicsBody.contactTestBitMask = kShipCategory;
			bullet.physicsBody.collisionBitMask = 0x0;
			break;
		default:
			bullet = nil;
			break;
	}


	return bullet;
}

#pragma mark - Scene Update

-(void)update:(NSTimeInterval)currentTime {
	if ([self isGameOver]) [self endGame];
	[self processContactsForUpdate:currentTime];
	[self processUserTapsForUpdate:currentTime];
	[self processUserMotionForUpdate:currentTime];
	[self moveInvadersForUpdate:currentTime];
	[self fireInvaderBulletsForUpdate:currentTime];
}

#pragma mark - Scene Update Helpers

// This method will get invoked by update:
-(void)moveInvadersForUpdate:(NSTimeInterval)currentTime {
	//1
	if (currentTime - self.timeOfLastMove < self.timePerMove) return;
	[self determineInvaderMovementDirection];

	//2
	[self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
		switch (self.invaderMovementDirection) {
			case InvaderMovementDirectionRight:
				node.position = CGPointMake(node.position.x + 10, node.position.y);
				break;
			case InvaderMovementDirectionLeft:
				node.position = CGPointMake(node.position.x - 10, node.position.y);
				break;
			case InvaderMovementDirectionDownThenLeft:
			case InvaderMovementDirectionDownThenRight:
				node.position = CGPointMake(node.position.x, node.position.y - 10);
				break;
			InvaderMovementDirectionNone:
			default:
				break;
		}
	}];

	//3
	self.timeOfLastMove = currentTime;
}

-(void)processUserMotionForUpdate:(NSTimeInterval)currentTime {
	//1
	SKSpriteNode* ship = (SKSpriteNode*)[self childNodeWithName:kShipName];
	//2
	CMAccelerometerData* data = self.motionManager.accelerometerData;
	//3
	if (fabs(data.acceleration.x) > 0.2) {
		//4 How do you move the ship?
		[ship.physicsBody applyForce:CGVectorMake(40.0 * data.acceleration.x, 0)];
		NSLog(@"How do you move the ship: %@", ship);
	}
}

-(void)processUserTapsForUpdate:(NSTimeInterval)currentTime {
	//1
	for (NSNumber* tapCount in [self.tapQueue copy]) {
		if ([tapCount unsignedIntegerValue] == 1) {
			//2
			[self fireShipBullets];
		}
		//3
		[self.tapQueue removeObject:tapCount];
	}
}

-(void)fireInvaderBulletsForUpdate:(NSTimeInterval)currentTime {
	SKNode* existingBullet = [self childNodeWithName:kInvaderFiredBulletName];
	//1
	if (!existingBullet) {
		//2
		NSMutableArray* allInvaders = [NSMutableArray array];
		[self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
			[allInvaders addObject:node];
		}];

		if ([allInvaders count] > 0) {
			//3
			NSUInteger allInvadersIndex = arc4random_uniform([allInvaders count]);
			SKNode* invader = [allInvaders objectAtIndex:allInvadersIndex];
			//4
			SKNode* bullet = [self makeBulletOfType:InvaderFiredBulletType];
			bullet.position = CGPointMake(invader.position.x, invader.position.y - invader.frame.size.height/2 + bullet.frame.size.height / 2);
			//5
			CGPoint bulletDestination = CGPointMake(invader.position.x, - bullet.frame.size.height / 2);
			//6
			[self fireBullet:bullet toDestination:bulletDestination withDuration:2.0 soundFileName:@"InvaderBullet.wav"];
		}
	}
}

-(void)processContactsForUpdate:(NSTimeInterval)currentTime {
	for (SKPhysicsContact* contact in [self.contactQueue copy]) {
		[self handleContact:contact];
		[self.contactQueue removeObject:contact];
	}
}

#pragma mark - Invader Movement Helpers

-(void)determineInvaderMovementDirection {
	//1
	__block InvaderMovementDirection proposedMovementDirection = self.invaderMovementDirection;

	//2
	[self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
		switch (self.invaderMovementDirection) {
			case InvaderMovementDirectionRight:
				//3
				if (CGRectGetMaxX(node.frame) >= node.scene.size.width - 1.0f) {
					proposedMovementDirection = InvaderMovementDirectionDownThenLeft;
					*stop = YES;
				}
				break;
			case InvaderMovementDirectionLeft:
				//4
				if (CGRectGetMinX(node.frame) <= 1.0f) {
					proposedMovementDirection = InvaderMovementDirectionDownThenRight;
					*stop = YES;
				}
				break;
			case InvaderMovementDirectionDownThenLeft:
				//5
				proposedMovementDirection = InvaderMovementDirectionLeft;
				[self adjustInvaderMovementToTimePerMove:self.timePerMove * 0.8];
				*stop = YES;
				break;
			case InvaderMovementDirectionDownThenRight:
				//6
				proposedMovementDirection = InvaderMovementDirectionRight;
				[self adjustInvaderMovementToTimePerMove:self.timePerMove * 0.8];
				*stop = YES;
				break;
			default:
				break;
		}
	}];

	//7
	if (proposedMovementDirection != self.invaderMovementDirection) {
		self.invaderMovementDirection = proposedMovementDirection;
	}
}

-(void)adjustInvaderMovementToTimePerMove:(NSTimeInterval)newTimePerMove {
	//1
	if (newTimePerMove <= 0) return;

	//2
	double ratio = self.timePerMove / newTimePerMove;
	self.timePerMove = newTimePerMove;

	[self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
		//3
		node.speed = node.speed * ratio;
	}];
}

#pragma mark - Bullet Helpers

-(void)fireBullet:(SKNode*)bullet toDestination:(CGPoint)destination withDuration:(NSTimeInterval)duration soundFileName:(NSString*)soundFileName {
	//1
	SKAction* bulletAction = [SKAction sequence:@[[SKAction moveTo:destination duration:duration],
												  [SKAction waitForDuration:3.0/60.0],
												  [SKAction removeFromParent]]];
	//2
	SKAction* soundAction  = [SKAction playSoundFileNamed:soundFileName waitForCompletion:YES];
	//3
	[bullet runAction:[SKAction group:@[bulletAction, soundAction]]];
	//4
	[self addChild:bullet];
}

-(void)fireShipBullets {
	SKNode* existingBullet = [self childNodeWithName:kShipFiredBulletName];
	//1
	if (!existingBullet) {
		SKNode* ship = [self childNodeWithName:kShipName];
		SKNode* bullet = [self makeBulletOfType:ShipFiredBulletType];
		//2
		bullet.position = CGPointMake(ship.position.x, ship.position.y + ship.frame.size.height - bullet.frame.size.height / 2);
		//3
		CGPoint bulletDestination = CGPointMake(ship.position.x, self.frame.size.height + bullet.frame.size.height / 2);
		//4
		[self fireBullet:bullet toDestination:bulletDestination withDuration:1.0 soundFileName:@"ShipBullet.wav"];
	}
}

#pragma mark - User Tap Helpers

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	// Intentional no-op
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	// Intentional no-op
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	// Intentional no-op
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch* touch = [touches anyObject];
	if (touch.tapCount == 1) [self.tapQueue addObject:@1];
}

#pragma mark - HUD Helpers

-(void)adjustScoreBy:(NSUInteger)points {
	self.score += points;
	SKLabelNode* score = (SKLabelNode*)[self childNodeWithName:kScoreHudName];
	score.text = [NSString stringWithFormat:@"Score: %04u", self.score];
}

-(void)adjustShipHealthBy:(CGFloat)healthAdjustment {
	//1
	self.shipHealth = MAX(self.shipHealth + healthAdjustment, 0);

	SKLabelNode* health = (SKLabelNode*)[self childNodeWithName:kHealthHudName];
	health.text = [NSString stringWithFormat:@"Health: %.1f%%", self.shipHealth * 100];
}

#pragma mark - Physics Contact Helpers

-(void)didBeginContact:(SKPhysicsContact *)contact {
	[self.contactQueue addObject:contact];
}

-(void)handleContact:(SKPhysicsContact*)contact {
	// Ensure you haven't already handled this contact and removed its nodes
	if (!contact.bodyA.node.parent || !contact.bodyB.node.parent) return;

	NSArray* nodeNames = @[contact.bodyA.node.name, contact.bodyB.node.name];
	if ([nodeNames containsObject:kShipName] && [nodeNames containsObject:kInvaderFiredBulletName]) {
		// Invader bullet hit a ship
		[self runAction:[SKAction playSoundFileNamed:@"ShipHit.wav" waitForCompletion:NO]];
		//1
		[self adjustShipHealthBy:-0.334f];
		if (self.shipHealth <= 0.0f) {
			//2
			[contact.bodyA.node removeFromParent];
			[contact.bodyB.node removeFromParent];
		} else {
			//3
			SKNode* ship = [self childNodeWithName:kShipName];
			ship.alpha = self.shipHealth;
			if (contact.bodyA.node == ship) [contact.bodyB.node removeFromParent];
			else [contact.bodyA.node removeFromParent];
		}
	} else if ([nodeNames containsObject:kInvaderName] && [nodeNames containsObject:kShipFiredBulletName]) {
		// Ship bullet hit an invader
		[self runAction:[SKAction playSoundFileNamed:@"InvaderHit.wav" waitForCompletion:NO]];
		[contact.bodyA.node removeFromParent];
		[contact.bodyB.node removeFromParent];
		//4
		[self adjustScoreBy:100];
	}
}

#pragma mark - Game End Helpers

-(BOOL)isGameOver {
	//1
	SKNode* invader = [self childNodeWithName:kInvaderName];

	//2
	__block BOOL invaderTooLow = NO;
	[self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
		if (CGRectGetMinY(node.frame) <= kMinInvaderBottomHeight) {
			invaderTooLow = YES;
			*stop = YES;
		}
	}];

	//3
	SKNode* ship = [self childNodeWithName:kShipName];

	//4
	return !invader || invaderTooLow || !ship;
}

-(void)endGame {
	//1
	if (!self.gameEnding) {
		self.gameEnding = YES;
		//2
		[self.motionManager stopAccelerometerUpdates];
		//3
		GameOverScene* gameOverScene = [[GameOverScene alloc] initWithSize:self.size];
		[self.view presentScene:gameOverScene transition:[SKTransition doorsOpenHorizontalWithDuration:1.0]];
	}
}

@end
