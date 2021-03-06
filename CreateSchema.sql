USE [master]
GO
/****** Object:  Database [biblepaypool]    Script Date: 10/10/2017 4:48:59 PM ******/
CREATE DATABASE [biblepaypool]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'biblepaypool', FILENAME = N'C:\DATA\biblepaypool.mdf' , SIZE = 277504KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'biblepaypool_log', FILENAME = N'C:\DATA\biblepaypool_log.ldf' , SIZE = 199296KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO
ALTER DATABASE [biblepaypool] SET COMPATIBILITY_LEVEL = 110
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [biblepaypool].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [biblepaypool] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [biblepaypool] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [biblepaypool] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [biblepaypool] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [biblepaypool] SET ARITHABORT OFF 
GO
ALTER DATABASE [biblepaypool] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [biblepaypool] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [biblepaypool] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [biblepaypool] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [biblepaypool] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [biblepaypool] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [biblepaypool] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [biblepaypool] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [biblepaypool] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [biblepaypool] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [biblepaypool] SET  DISABLE_BROKER 
GO
ALTER DATABASE [biblepaypool] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [biblepaypool] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [biblepaypool] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [biblepaypool] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [biblepaypool] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [biblepaypool] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [biblepaypool] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [biblepaypool] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [biblepaypool] SET  MULTI_USER 
GO
ALTER DATABASE [biblepaypool] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [biblepaypool] SET DB_CHAINING OFF 
GO
ALTER DATABASE [biblepaypool] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [biblepaypool] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
USE [biblepaypool]
GO
/****** Object:  StoredProcedure [dbo].[InsWork]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
       
	   
	   
	  CREATE procedure [dbo].[InsWork](@NetworkID varchar(100), @minerid uniqueidentifier, @ThreadID float, @MinerName varchar(200), @HashTarget varchar(200), @WorkId uniqueidentifier, @IP varchar(100)) 

				AS 
	
	 BEGIN
		Insert into Work (id,solution,networkid,minerid,minername,updated,added,hashtarget,starttime,endtime,hps,threadid,ip) 
		values (@workid,newid(),@networkid,@minerid,@minerName,getdate(),getdate(),@HashTarget,getdate(),null,0,@ThreadID,@IP)
	 END
	 


                   
GO
/****** Object:  StoredProcedure [dbo].[Maintenance]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

       
	   
	   
	  CREATE procedure [dbo].[Maintenance]
	  as
	
-- Defrag the most active tables

dbcc indexdefrag ( biblepaypool,'work','ClusteredIndex-20170918-211644')

dbcc indexdefrag (biblepaypool,'miners','UQ__Miners__F3DBC572AA8A8A98')

dbcc indexdefrag (biblepaypool,'block_distribution','UQ__block_di__7F957A3945A68BA1')
-- Archive the old info



insert into block_distribution_history
select  * from block_distribution  where updated < getdate()-50

delete from block_distribution where updated < getdate()-50

-- Archive the transaction Log

-- Run a report on Fragmentation


SELECT dbschemas.[name] as 'Schema',
dbtables.[name] as 'Table',
dbindexes.[name] as 'Index',
indexstats.avg_fragmentation_in_percent,
indexstats.page_count
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS indexstats
INNER JOIN sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
INNER JOIN sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
INNER JOIN sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
AND indexstats.index_id = dbindexes.index_id
WHERE indexstats.database_id = DB_ID()
ORDER BY indexstats.avg_fragmentation_in_percent desc





-- See the Performance Monitor: CTRL+ALT+A 



                   

GO
/****** Object:  StoredProcedure [dbo].[UpdatePool]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
      
	CREATE procedure [dbo].[UpdatePool](@sNetwork varchar(100)) 

				AS 
	

IF  (Select 	datediff(second, system.updated,getdate()) from system where systemkey='leaderboard_updated') > 60
BEGIN
BEGIN TRANSACTION;   
	update system set updated=getdate() where systemkey='leaderboard_updated'

	--Delete old work from all chains:  
	Delete from Work where starttime < dateadd(second,-1600,getdate())

	--Set the decay work on completed work
	Update work set Age = (100 - (((datediff(second, endtime,getdate())/50.01)*1.1)))/100  where 1=1 
	--Set the weight of each hashtarget
	Update work set chainwork = dbo.getweight(hashtarget) where chainwork is null
	
	--Set the shares done by worker
    UPDATE Work SET work.shares = (Select count(*) From Work  w with (nolock)  where w.minerid=work.minerid and endtime is not null and networkid='test') where networkid='test'
	UPDATE Work SET work.shares = (Select count(*) From Work  w with (nolock)  where w.minerid=work.minerid and endtime is not null and networkid='main') where networkid='main'

	--Set the totalshares of all workers
	Update work set work.totalshares = (Select count(*) from work with (nolock)  where endtime is not null and networkid='test') where networkid='test'
	Update work set work.totalshares = (Select count(*) from work with (nolock)  where endtime is not null and networkid='main') where networkid='main'

	--Set the elapsed time in seconds for work sent by pool that is completed
	Update work set work.HpsSecs = (Datediff(s, starttime, endtime+.0001)+0.0001) where endtime is not null

	--Set the simulated HPS for individual shares
	Update work set work.hpsRoot = 100000/work.HpsSecs where work.hpssecs is not null

	--Set the synthetic HPS (Age decayed) per completed record
	update work Set HpsEngineered =  shares* 500
	update work set HPS = HpsEngineered * Age * 1.30 where 1=1

	-- Copy the sum of the HPS for the work records per miner back to the user record (this is used for block payments)
    Update Users Set Users.HpsTest=(
					 select sum(h) from (	Select avg(work.hps) h,miners.id From Work with (nolock) 
					 inner Join miners On Work.minerid=miners.id And miners.UserId=users.id Where EndTime Is Not null 
	  	  			 And hps > 0 And Work.networkid='test' group by miners.id) a ) 
	-- Copy for Main Chain
	Update Users Set Users.HpsMain=(
					 select sum(h) from (	Select avg(work.hps) h,miners.id From Work with (nolock) 
					 inner Join miners On Work.minerid=miners.id And miners.UserId=users.id Where EndTime Is Not null 
	  	  			 And hps > 0 And Work.networkid='main' group by miners.id) a ) 


	-- Copy the sum of the server HPS records back to user record (used for parentheses in Stats in block_distribution)
    Update Users set Users.BoxHpstest = (
			 select sum(h) from (	Select avg(work.boxhps) h,miners.id From Work with (nolock) 
					 inner Join miners On Work.minerid=miners.id And miners.UserId=users.id Where EndTime Is Not null 
	  	  			 And hps > 0 And Work.networkid='test' group by miners.id) a ) 

	Update Users set Users.BoxHpsMain = (
			 select sum(h) from (	Select avg(work.boxhps) h,miners.id From Work with (nolock) 
					 inner Join miners On Work.minerid=miners.id And miners.UserId=users.id Where EndTime Is Not null 
	  	  			 And hps > 0 And Work.networkid='main' group by miners.id) a ) 
 
 	-- Maintain a record of HPS per mining thread (used for police subsystem)
	Update Users set Users.ThreadHpsTest  = (Select avg(work.ThreadHPS) from Work  with (nolock) 
         	 inner join miners on work.minerid=miners.id  And Miners.UserId=Users.Id where endtime Is Not null and work.networkid='test')

	Update Users set Users.ThreadHpsMain  = (Select avg(work.ThreadHPS) from Work  with (nolock) 
         	 inner join miners on work.minerid=miners.id  And Miners.UserId=Users.Id where endtime Is Not null and work.networkid='main')

	-- Maintain a sum of thread counts per miner
	Update Miners set Miners.BoxHPStest = round((Select isnull(avg(work.boxhps),0) from Work with (nolock)  where Work.MinerId = Miners.Id and work.networkid = 'test'),2)
	Update Miners set Miners.BoxHPSmain = round((Select isnull(avg(work.boxhps),0) from Work with (nolock)  where Work.MinerId = Miners.Id and work.networkid = 'main'),2)
	
	Update Users Set Users.ThreadCountTest = (Select sum(miners.Threadstest)+1 from Miners where Miners.UserId=Users.Id)
	Update Users Set Users.ThreadBoxHPStest=Users.ThreadCounttest*Users.ThreadHPStest


	-- BIBLEPAY POLICE DEPARTMENT SECTION

	-- Delete work solved with modified clients reporting 0 total threads with work across threads
	Delete from work where minername in (select minername from (select max(threadid) t, count(*) c,minername from work group by minername) a where t = 0  and c > 100) and endtime is not null and starttime < dateadd(second,-500,getdate())

	--Leaderboard


drop table leaderboardmain
Select 
newid() as id,
Users.username,
MinerName,
Round(Avg(work.BoxHPS),2) HPS,
round(avg(work.hps),2) as HPS2,
count(*) as shares,
max(endtime) as Reported,
max(endtime) as Added,
max(endtime) as Updated,
Users.Cloak 
into Leaderboardmain
from Work with (nolock) 
 inner join Miners with (nolock) on Miners.id = work.minerid  
 inner join Users with (nolock) on Miners.Userid = Users.Id  
 where Work.BoxHps > 0 and  work.hps > 0 and work.networkid='main'
   Group by Users.cloak,users.username,minername order by avg(work.boxhps) desc,MinerName



drop table leaderboardtest
Select 
newid() as id,
Users.username,MinerName,
Round(Avg(work.BoxHPS),2) HPS,
round(avg(work.hps),2) as HPS2,
count(*) as shares,
max(endtime) as Reported,
max(endtime) as Added,
max(endtime) as Updated,
Users.Cloak 
into Leaderboardtest
from Work with (nolock) 
 inner join Miners with (nolock) on Miners.id = work.minerid  
 inner join Users with (nolock) on Miners.Userid = Users.Id  
 where Work.BoxHps > 0 and  work.hps > 0 and work.networkid='test'
   Group by Users.cloak,users.username,minername order by avg(work.boxhps) desc,MinerName


COMMIT TRANSACTION;


END

GO
/****** Object:  UserDefinedFunction [dbo].[GetWeight]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetWeight](@shashtarget varchar(100)) 
       RETURNS int 
AS 
BEGIN; 
  DECLARE @Result float; 

  declare @sChunk varchar(10);
  set @sChunk = substring(@shashtarget,2,4);
  declare @component1 float;
  declare @in1 float;
  declare @in2 float;
  declare @in3 float;
  declare @in4 float;
  set @in1 = 10-cast(substring(@sChunk,1,1) as float);
  set @in2 = 10-cast(substring(@sChunk,2,1) as float);
  set @in3 = 10-cast(substring(@sChunk,3,1) as float);
  set @in4 = 10-cast(substring(@sChunk,4,1) as float);

  
  IF @in1 = 10  
  BEGIN
       SET @in1 = 325
  END

  IF @in1 = 9
  BEGIN
	SET @in1 = 256
  END

  if @in1 = 8
  BEGIN 
	set @in1 = 100
  END

  if @in1 = 7
  BEGIN
	set @in1 = 80
  END

  if @in1 = 6
  BEGIN 
  set @in1=60
  END

  if @in1=5
  BEGIN
	set @in1=50
  END

  set @component1 = (@in1 * 512) + (@in2 * 256) + (@in3 * 128) + (@in1 * 64);
  set @component1 = @component1 * 7.5;
  SET @Result = @component1;
  RETURN @Result; 
END;



GO
/****** Object:  Table [dbo].[Audit]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Audit](
	[id] [uniqueidentifier] NULL,
	[updated] [datetime] NULL,
	[ChainWork] [decimal](20, 0) NULL,
	[Elapsed] [float] NULL,
	[ElapsedClient] [float] NULL,
	[HPSClient] [float] NULL,
	[CalcHPS] [float] NULL,
	[networkid] [varchar](20) NULL,
	[IP] [varchar](100) NULL,
	[minername] [varchar](100) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[audit2]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[audit2](
	[id] [uniqueidentifier] NULL,
	[TableName] [varchar](200) NULL,
	[ObjectID] [uniqueidentifier] NULL,
	[Changes] [varchar](4000) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[Updated] [datetime] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[block_distribution]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[block_distribution](
	[id] [uniqueidentifier] NULL,
	[height] [float] NULL,
	[updated] [datetime] NULL,
	[block_subsidy] [money] NULL,
	[subsidy] [money] NULL,
	[Paid] [datetime] NULL,
	[NetworkID] [varchar](30) NULL,
	[hps] [float] NULL,
	[userid] [uniqueidentifier] NULL,
	[stats] [varchar](3501) NULL,
	[UserName] [varchar](200) NULL,
	[PPH] [float] NULL,
UNIQUE NONCLUSTERED 
(
	[height] ASC,
	[userid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[block_distribution_history]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[block_distribution_history](
	[id] [uniqueidentifier] NULL,
	[height] [float] NULL,
	[updated] [datetime] NULL,
	[block_subsidy] [money] NULL,
	[subsidy] [money] NULL,
	[Paid] [datetime] NULL,
	[NetworkID] [varchar](30) NULL,
	[hps] [float] NULL,
	[userid] [uniqueidentifier] NULL,
	[stats] [varchar](3501) NULL,
	[UserName] [varchar](200) NULL,
	[PPH] [float] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[blocks]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[blocks](
	[id] [uniqueidentifier] NULL,
	[height] [float] NULL,
	[updated] [datetime] NULL,
	[subsidy] [money] NULL,
	[minerid] [uniqueidentifier] NULL,
	[NetworkID] [varchar](50) NULL,
UNIQUE NONCLUSTERED 
(
	[height] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[dictionary]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[dictionary](
	[Id] [uniqueidentifier] NULL,
	[TableName] [varchar](100) NULL,
	[FieldName] [varchar](100) NULL,
	[DataType] [varchar](50) NULL,
	[ParentTable] [varchar](100) NULL,
	[ParentFieldName] [varchar](100) NULL,
	[ParentGuiField1] [varchar](100) NULL,
	[ParentGuiField2] [varchar](100) NULL,
	[Caption] [varchar](200) NULL,
	[FieldSize] [numeric](6, 0) NULL,
	[FieldRows] [numeric](6, 0) NULL,
	[FieldCols] [numeric](6, 0) NULL,
	[ErrorText] [varchar](200) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Expense]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Expense](
	[id] [uniqueidentifier] NULL,
	[BatchId] [uniqueidentifier] NULL,
	[Added] [date] NULL,
	[Amount] [money] NULL,
	[OrphanPremiumsPaid] [float] NULL,
	[NewSponsorships] [float] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[invalidsolution]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[invalidsolution](
	[id] [uniqueidentifier] NULL,
	[added] [datetime] NULL,
	[IP] [varchar](100) NULL,
	[solution] [varchar](700) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Leaderboardmain]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Leaderboardmain](
	[id] [uniqueidentifier] NULL,
	[username] [varchar](100) NULL,
	[MinerName] [varchar](200) NULL,
	[HPS] [float] NULL,
	[HPS2] [float] NULL,
	[shares] [int] NULL,
	[Reported] [datetime] NULL,
	[Added] [datetime] NULL,
	[Updated] [datetime] NULL,
	[Cloak] [numeric](1, 0) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Leaderboardtest]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Leaderboardtest](
	[id] [uniqueidentifier] NULL,
	[username] [varchar](100) NULL,
	[MinerName] [varchar](200) NULL,
	[HPS] [float] NULL,
	[HPS2] [float] NULL,
	[shares] [int] NULL,
	[Reported] [datetime] NULL,
	[Added] [datetime] NULL,
	[Updated] [datetime] NULL,
	[Cloak] [numeric](1, 0) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Letters]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Letters](
	[id] [uniqueidentifier] NULL,
	[Body] [varchar](8000) NULL,
	[added] [datetime] NULL,
	[orphanid] [varchar](40) NULL,
	[userid] [uniqueidentifier] NULL,
	[username] [varchar](100) NULL,
	[name] [varchar](400) NULL,
	[Upvote] [float] NOT NULL,
	[Downvote] [float] NOT NULL,
	[Approved] [numeric](1, 0) NULL,
	[Sent] [numeric](1, 0) NULL,
	[Paid] [numeric](1, 0) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LettersInbound]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LettersInbound](
	[id] [uniqueidentifier] NULL,
	[OrphanID] [varchar](40) NULL,
	[URL] [varchar](255) NULL,
	[Name] [varchar](200) NULL,
	[added] [date] NULL,
	[Page] [float] NULL,
	[Updated] [date] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LetterWritingFees]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LetterWritingFees](
	[id] [uniqueidentifier] NULL,
	[height] [float] NULL,
	[added] [datetime] NULL,
	[amount] [money] NULL,
	[networkid] [varchar](70) NULL,
	[quantity] [float] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Lookup]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Lookup](
	[id] [uniqueidentifier] NULL,
	[TableName] [varchar](100) NULL,
	[Field] [varchar](100) NULL,
	[FieldList] [varchar](999) NULL,
	[Method] [varchar](200) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[menu]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[menu](
	[id] [uniqueidentifier] NULL,
	[Hierarchy] [varchar](200) NULL,
	[Classname] [varchar](200) NULL,
	[added] [datetime] NULL,
	[DefaultURL] [varchar](255) NULL,
	[Method] [varchar](200) NULL,
	[deleted] [numeric](1, 0) NULL,
	[ordinal] [float] NULL,
	[Accountability] [numeric](1, 0) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Miners]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Miners](
	[id] [uniqueidentifier] NULL,
	[Userid] [uniqueidentifier] NULL,
	[username] [varchar](100) NULL,
	[updated] [datetime] NULL,
	[added] [datetime] NULL,
	[LastLogin] [datetime] NULL,
	[workeraddress] [varchar](100) NULL,
	[Notes] [varchar](255) NULL,
	[ThreadsMain] [float] NULL,
	[ThreadsTest] [float] NULL,
	[BoxHPSMain] [float] NULL,
	[BoxHPSTest] [float] NULL,
	[getworks] [float] NULL,
	[Disabled] [numeric](1, 0) NULL,
	[HighHash] [float] NULL,
UNIQUE NONCLUSTERED 
(
	[username] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[organization]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[organization](
	[id] [uniqueidentifier] NULL,
	[Name] [varchar](200) NULL,
	[Theme] [varchar](100) NULL,
	[Added] [datetime] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[OrphanAuction]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OrphanAuction](
	[id] [uniqueidentifier] NULL,
	[updated] [datetime] NULL,
	[BBPAmount] [money] NULL,
	[BTCRaised] [money] NULL,
	[BTCPrice] [money] NULL,
	[EstimatedOrphanBenefit] [float] NULL,
	[Amount] [money] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Orphans]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Orphans](
	[id] [uniqueidentifier] NULL,
	[OrphanID] [varchar](100) NULL,
	[Commitment] [money] NULL,
	[Notes] [varchar](1000) NULL,
	[Name] [varchar](200) NULL,
	[URL] [varchar](255) NULL,
	[added] [datetime] NULL,
	[updated] [datetime] NULL,
	[Frequency] [varchar](50) NULL,
	[Charity] [varchar](100) NULL,
	[Organization] [varchar](125) NULL,
	[NeedWritten] [float] NULL,
UNIQUE NONCLUSTERED 
(
	[OrphanID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Page]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Page](
	[id] [uniqueidentifier] NULL,
	[Name] [varchar](200) NULL,
	[Sections] [varchar](1000) NULL,
	[deleted] [numeric](1, 0) NULL,
	[Organization] [uniqueidentifier] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Picture]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Picture](
	[id] [uniqueidentifier] NULL,
	[added] [datetime] NULL,
	[deleted] [numeric](1, 0) NULL,
	[addedby] [uniqueidentifier] NULL,
	[organization] [uniqueidentifier] NULL,
	[ParentId] [uniqueidentifier] NULL,
	[Updated] [datetime] NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[Dummy] [varchar](20) NULL,
	[Name] [varchar](400) NULL,
	[Extension] [varchar](5) NULL,
	[SAN] [varchar](500) NULL,
	[FullFileName] [varchar](100) NULL,
	[Size] [float] NULL,
	[URL] [varchar](300) NULL,
	[ParentType] [varchar](100) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Section]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Section](
	[id] [uniqueidentifier] NULL,
	[Name] [varchar](200) NULL,
	[Fields] [varchar](750) NULL,
	[deleted] [numeric](1, 0) NULL,
	[TableName] [varchar](200) NULL,
	[Organization] [uniqueidentifier] NULL,
	[DependentSection] [varchar](100) NULL,
	[DependentFields] [varchar](500) NULL,
	[Class] [varchar](200) NULL,
	[Method] [varchar](200) NULL,
	[FieldBackup] [varchar](3000) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[SectionRules]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SectionRules](
	[id] [uniqueidentifier] NULL,
	[SectionID] [uniqueidentifier] NULL,
	[RuleText] [varchar](4000) NULL,
	[deleted] [numeric](1, 0) NULL,
	[Organization] [uniqueidentifier] NULL,
	[Added] [datetime] NULL,
	[addedby] [uniqueidentifier] NULL,
	[Updated] [datetime] NULL,
	[updatedby] [uniqueidentifier] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[System]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[System](
	[id] [uniqueidentifier] NULL,
	[SystemKey] [varchar](100) NULL,
	[Value] [varchar](255) NULL,
	[Updated] [datetime] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Ticket]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Ticket](
	[id] [uniqueidentifier] NULL,
	[Name] [varchar](250) NULL,
	[Description] [varchar](250) NULL,
	[SubmittedBy] [uniqueidentifier] NULL,
	[AssignedTo] [uniqueidentifier] NULL,
	[Disposition] [varchar](200) NULL,
	[Added] [datetime] NULL,
	[Updated] [datetime] NULL,
	[Deleted] [numeric](1, 0) NULL,
	[TicketNumber] [varchar](100) NULL,
	[Body] [varchar](4000) NULL,
	[UserText1] [varchar](200) NULL,
	[UpdatedBy] [uniqueidentifier] NULL,
	[ParentID] [uniqueidentifier] NULL,
	[Organization] [uniqueidentifier] NULL,
	[AddedBy] [uniqueidentifier] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[TicketHistory]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TicketHistory](
	[id] [uniqueidentifier] NULL,
	[Body] [varchar](4000) NULL,
	[added] [datetime] NULL,
	[updated] [datetime] NULL,
	[Deleted] [numeric](1, 0) NULL,
	[AssignedTo] [uniqueidentifier] NULL,
	[Disposition] [varchar](200) NULL,
	[ParentId] [uniqueidentifier] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[TransactionLog]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TransactionLog](
	[id] [uniqueidentifier] NULL,
	[transactionid] [varchar](200) NULL,
	[username] [varchar](100) NULL,
	[userid] [uniqueidentifier] NULL,
	[transactiontype] [varchar](100) NULL,
	[destination] [varchar](100) NULL,
	[amount] [money] NULL,
	[oldbalance] [money] NULL,
	[newbalance] [money] NULL,
	[added] [datetime] NULL,
	[updated] [datetime] NULL,
	[rake] [money] NULL,
	[NetworkID] [varchar](30) NULL,
	[Notes] [varchar](3000) NOT NULL,
	[Height] [float] NULL,
UNIQUE NONCLUSTERED 
(
	[transactionid] ASC,
	[NetworkID] ASC,
	[transactiontype] ASC,
	[amount] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Users]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Users](
	[id] [uniqueidentifier] NULL,
	[username] [varchar](100) NULL,
	[password] [varchar](100) NULL,
	[Email] [varchar](100) NULL,
	[updated] [datetime] NULL,
	[added] [datetime] NULL,
	[deleted] [numeric](1, 0) NULL,
	[FailedLoginAttempts] [numeric](4, 0) NULL,
	[LastLogin] [datetime] NULL,
	[WithdrawalAddress] [varchar](100) NULL,
	[LastFailedLoginDate] [datetime] NULL,
	[UserText1] [varchar](255) NULL,
	[ThreadBoxHPS] [float] NULL,
	[BoxHPSMain] [float] NULL,
	[BoxHPSTest] [float] NULL,
	[HPSMain] [float] NULL,
	[HPSTest] [float] NULL,
	[ThreadHPSMain] [float] NULL,
	[ThreadHPSTest] [float] NULL,
	[ThreadCountMain] [float] NULL,
	[ThreadCountTest] [float] NULL,
	[BalanceMain] [money] NULL,
	[Balancetest] [money] NULL,
	[ThreadBoxHPStest] [float] NULL,
	[HomogenizedHPSMain] [float] NULL,
	[HomogenizedHPSTest] [float] NULL,
	[ThreadBoxHPSMain] [float] NULL,
	[Cloak] [numeric](1, 0) NULL,
	[Organization] [uniqueidentifier] NULL,
	[Bug] [money] NULL,
UNIQUE NONCLUSTERED 
(
	[Email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[username] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Votes]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Votes](
	[id] [uniqueidentifier] NULL,
	[added] [datetime] NULL,
	[userid] [uniqueidentifier] NULL,
	[letterid] [uniqueidentifier] NULL,
	[upvote] [float] NOT NULL,
	[downvote] [float] NOT NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Work]    Script Date: 10/10/2017 4:49:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Work](
	[id] [uniqueidentifier] NULL,
	[minerid] [uniqueidentifier] NULL,
	[minername] [varchar](200) NULL,
	[updated] [datetime] NULL,
	[added] [datetime] NULL,
	[hashtarget] [varchar](200) NULL,
	[starttime] [datetime] NULL,
	[endtime] [datetime] NULL,
	[hps] [float] NULL,
	[networkid] [varchar](20) NULL,
	[ThreadID] [float] NULL,
	[ThreadStart] [float] NULL,
	[HashCounter] [float] NULL,
	[TimerStart] [float] NULL,
	[TimerEnd] [float] NULL,
	[ThreadHPS] [float] NULL,
	[BoxHPS] [float] NULL,
	[ThreadWork] [float] NULL,
	[Age] [float] NULL,
	[Shares] [float] NULL,
	[HpsRoot] [float] NULL,
	[hpssecs] [float] NULL,
	[chainwork] [float] NULL,
	[totalshares] [float] NULL,
	[HPSEngineered] [float] NULL,
	[IP] [varchar](40) NULL,
	[Audited] [numeric](1, 0) NULL,
	[SharePercent] [float] NULL,
	[AvgShares] [float] NULL,
	[AvgHPS] [float] NULL,
	[Solution] [varchar](500) NULL,
	[solution2] [varchar](500) NULL,
	[OS] [varchar](50) NULL,
	[Validated] [numeric](1, 0) NULL,
	[Error] [varchar](300) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Index [ClusteredIndex-20170918-211644]    Script Date: 10/10/2017 4:49:00 PM ******/
CREATE CLUSTERED INDEX [ClusteredIndex-20170918-211644] ON [dbo].[Work]
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UX_Entries]    Script Date: 10/10/2017 4:49:00 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Entries] ON [dbo].[LettersInbound]
(
	[OrphanID] ASC,
	[added] ASC,
	[Page] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Letters] ADD  DEFAULT ((0)) FOR [Upvote]
GO
ALTER TABLE [dbo].[Letters] ADD  DEFAULT ((0)) FOR [Downvote]
GO
ALTER TABLE [dbo].[Letters] ADD  DEFAULT ((0)) FOR [Approved]
GO
ALTER TABLE [dbo].[Letters] ADD  DEFAULT ((0)) FOR [Sent]
GO
ALTER TABLE [dbo].[Letters] ADD  DEFAULT ((0)) FOR [Paid]
GO
ALTER TABLE [dbo].[menu] ADD  DEFAULT ((0)) FOR [ordinal]
GO
USE [master]
GO
ALTER DATABASE [biblepaypool] SET  READ_WRITE 
GO
